# gitlab + runner on docker
---
- docker + docker-composeはインストール済みとする

## docker-compose.yml
1. ~/docker/gitlab/docker-compose.ymlファイルを作成
	- gitlab-ceとgitlab-runnerは同じdocker-compose.ymlに定義すること
		- 同じdocker networkに配置されないとサービス名でのアクセスが出来なくなる
	- runnerのvolumesでdocker.sockのマウントをすること
		- docker in dockerでrunnerがdockerコマンドを使う場合は必須
		- runner executorにdockerを使わないならdocker.sockのマウントは不要

```yml
version: '3.7'
services:
	# サービス名、この名前でコンテナ同士がアクセス出来る
    gitlab:
		# dockerHubのimage名とversion指定
        image: gitlab/gitlab-ce:latest
		# OS起動時にコンテナを自動起動する設定
        restart: always
		# コンテナ名
        container_name: gitlab
		# ホストのディレクトリをコンテナにマウントさせる設定
        volumes:
            - ./gitlab_etc:/etc/gitlab
            - ./gitlab_log:/var/log/gitlab
            - ./gitlab_opt:/var/opt/gitlab
        # ホストからコンテナへのポート番号のリダイレクト設定
        ports:
            - "10080:80"
            - "10022:22"
    runner:
        image: gitlab/gitlab-runner
        restart: always
        container_name: gitlab-runner
        volumes:
            - ./runner_config:/etc/gitlab-runner
            - /var/run/docker.sock:/var/run/docker.sock
        # runnerはgitlabの後で起動して欲しいので依存コンテナを指定する
        depends_on:
            - gitlab
```

2. docker-compose.ymlファイルのある~/docker/gitlab/ディレクトリで以下のコマンドを実行
```
docker-compose up -d
```

## runnerの登録
1. gitlabがrunner向けに発行するトークン文字列を確認する
	- gitlabプロジェクト >> 設定 >> CI/CD >> Runnerのページで確認可能

2. 実行中gitlab-runnerコンテナの中に入る
```
docker exec -it gitlab-runner bash
```

3. dockerで実行されるrunnerを新規登録する
	- docker-network-modeで指定するのはgitlab, gitlab-runnerが所属しているdocker network名
		- `docker network list`でネットワーク一覧を確認可能
		- `docker network inspect {ネットワーク名}`で所属するコンテナを確認可能
		- この設定が無いとrunnerが起動したビルド/テスト実行コンテナがgitlab(+runner)とは異なるネットワークに配置されるため、ソースのcloneでURLが解決できない
	- ここでは、android向けにdockerで実行するrunnerを登録する
	- 他にもshellを実行するrunner等がある
```
gitlab-runner register \
    --non-interactive \
    --name docker-android-runner \
    --url "http://gitlab" \
    --registration-token "gitlabのrunner設定ページで確認したトークン文字列" \
    --executor docker \
    --docker-image "nginx:alpine" \
    --tag-list android \
    --docker-network-mode "gitlab_default" \
    --docker-pull-policy "if-not-present"
```

## gitlab-ci.yml
1. リポジトリのルートにファイルを追加する
	- "+"アイコン >> 新規ファイル >>
		- select a template type >> .gitlab-ci.yml
		- apply a template >> General/Android
	- commit changes

2. .gitlab-ci.ymlファイルにrunnerのタグを追加する
	- gitlab-runner registerコマンドで登録した際、tag-listに指定したタグ名を追記する
	- 以下の例ではlintDebug(コード整形), assembleDebug(デバッグビルド), debugTests(テスト実行)という3個のjobについて、`tags: - android`を追加している

```yml
lintDebug:
  stage: build
  script:
    - ./gradlew -Pci --console=plain :app:lintDebug -PbuildDir=lint
  tags:
    - android

assembleDebug:
  stage: build
  script:
    - ./gradlew assembleDebug
  artifacts:
    paths:
      - app/build/outputs/
  tags:
    - android

debugTests:
  stage: test
  script:
    - ./gradlew -Pci --console=plain :app:testDebug
  tags:
    - android
```

## gitlab CIパイプラインを実行する
- gitlabプロジェクト >> CI/CD >> パイプライン >> パイプライン実行
- デフォルトでは.gitlab-ci.ymlで定義したjob(lintDebug, assembleDebug, debugTests)が順次実行される
- jobのページに入ると実行中のコンソール状況をブラウザ上で確認できる
