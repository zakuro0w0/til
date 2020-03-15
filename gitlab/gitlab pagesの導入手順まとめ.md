# gitlab pages

## pagesの有効化に必要な設定
- pages_external_url, inplace_chrootの設定があればOK
	- これをやらないとリポジトリ設定メニューにpagesは出てこない

```yml:docker-compose.yml
version: '3.7'
services:
    gitlab:
        image: gitlab/gitlab-ce:latest
        restart: always
        container_name: gitlab
        environment:
            GITLAB_OMNIBUS_CONFIG: |
                pages_external_url 'http://localhost:18080'
				gitlab_pages['inplace_chroot'] = true
```

## docker-compose.yml全体
```yml:docker-compose.yml
version: '3.7'
services:
    gitlab:
        image: gitlab/gitlab-ce:latest
        restart: always
        container_name: gitlab
        environment:
            GITLAB_OMNIBUS_CONFIG: |
				# for gitlab pages setting
                pages_external_url 'http://localhost:18080'
				gitlab_pages['inplace_chroot'] = true
				# for plantUML setting
                nginx['custom_gitlab_server_config'] = "location /-/plantuml/ { \n    proxy_cache off; \n    proxy_pass  http://plantuml:8080/; \n}\n"
        volumes:
            - ./gitlab_etc:/etc/gitlab
            - ./gitlab_log:/var/log/gitlab
            - ./gitlab_opt:/var/opt/gitlab
        ports:
            - "10080:80"
            - "10022:22"
            - "18080:18080"
    runner:
        image: gitlab/gitlab-runner
        restart: always
        container_name: gitlab-runner
        volumes:
            - ./runner_config:/etc/gitlab-runner
            - /var/run/docker.sock:/var/run/docker.sock
        depends_on:
            - gitlab
    plantuml:
        image: 'plantuml/plantuml-server:tomcat'
        container_name: plantuml
    apihook:
        build:
            context: ./custom_webhook
            dockerfile: DockerFile
        container_name: apihook
        ports:
            - "8080:80"
        volumes:
                - ./custom_webhook/apihook/:/home/vagrant/apihook

```

## gitlabコンテナの再起動
- docker-compose.ymlを書き換えたらコンテナを再起動する

```
docker-compose up -d
```

## .gitlab-ci.yml
```yml:.gitlab-ci.yml
before_script:
	# for each job after script execution
	- apt-get --quiet install --yes ruby


# pagesに公開する成果物を作成するjobの定義
unitTest:
  stage: test
  script:
  	# unitTestを実行させる
    - ./gradlew test
  after_script:
  	# unitTestレポートをpublic/配下に移動させるscript
    - ruby ./unitTest.rb module1 module2 module3
  artifacts:
    paths:
      - public
  tags:
  	# jobを実行するrunnerのtag指定
    - android

# public/配下に集められた成果物を公開するjobの定義
pages:
  stage: deploy
  script:
    - echo "pages job!!"
  artifacts:
    paths:
      - public
  only:
    - master
  tags:
  	# jobを実行するrunnerのtag指定
    - android
```


## after_script用のrubyファイル
- jobを実行した後、artifactをpublic/配下に移しておく必要がある
- projectのmodule毎に必要なので、scriptにまとめておき、scriptに対してmodule名の配列をコマンドライン引数として渡すのが簡単
- rubyファイルは.gitlab-ci.ymlと同じ階層(リポジトリ直下)に配置する

```ruby:unitTest.rb
# コマンドライン引数はモジュール名の配列として扱う
modules = ARGV

# public/配下にbranch名でディレクトリを切るためのパス
path = "public/$CI_COMMIT_REF_NAME/unitTest"

modules.each{ |mod|
	# jobのartifactをpagesで公開するためのディレクトリを生成する
	`mkdir -p #{path}/#{mod}/`
	# artifactを公開用ディレクトリに移動
	`mv #{mod}/build/reports/tests/testReleaseUnitTest/* #{path}/#{mod}/`
}
```

## pipelineの実行
- .gitlab-ci.yml(+ruby script)を変更したらリポジトリにpushする
- pushに伴いpipelineが実行されるので、pagesのdeployが完了するまで待つ

## pagesのURL確認
- pipeline完了後、リポジトリの設定 >> pagesメニューから確認可能
- 例えば`http://localhost:9000/top_group/sub_group/repository.git`だった場合は
- `http://top_group.localhost:18080/sub_group/repository/`がpagesのdocumentRootに対するURLとなる

## pagesの運用方法
- documentRoot/index.htmlにdeployされた各種コンテンツへのリンクを貼る手段もあるが、branch名でディレクトリを切ったり、moduleがproject毎に異なるため少し面倒
- リポジトリ毎に設けられているWikiのページにて、コンテンツへのリンクを貼るのが簡単

## deployされたコンテンツの階層確認
- Wikiからリンクを貼る際、コンテンツのファイルツリー構造を知りたい場合がある
- pipelineのpages artifactをダウンロードし、zipを解凍すれば構造が分かる
	- public/がdocumentRootに相当する

## gitlab pagesの注意点
- Wikiにbranch毎のページを設け、pagesにdeployしたコンテンツへのリンクを貼る運用だと都合が悪い点があると発覚した
- pages配下のコンテンツはpages jobが実行される度に全てリセットされるため、branch毎の保存は出来ない
- branch Aのpipelineが実行された後、branch Bのpipelineを実行するとbranch Aのpages配下コンテンツは消えてる
	- 最後にpipelineを実行したbranchのコンテンツのみがpagesに保存される仕組み
	- その時々のメインストリームになってるbranchのみをWikiで追跡するのが良いだろう
