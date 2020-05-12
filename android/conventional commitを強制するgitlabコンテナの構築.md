# conventional commitを強制するgitlabコンテナの構築
## やりたいこと
- 自前の環境にhostしたgitlabにて、[conventional commit](https://www.conventionalcommits.org/ja/v1.0.0-beta.4/)を強制させたい
- 更なる目論見として、conventional commitを前提としたcommit messageを解析し、バイナリの自動versioningをしたい

## どうやって実現しているか
- conventional commitに準拠しているかの確認は、npm packageのcommitlintを使う
- また、commitlintの実行はserver側git hookであるpre-receive scriptにて行う
  - huskyはserver側git hookに対応していないため、素のgit hookから直接commitlintを実行しなければならない

## なぜgitlab server側での実現なのか
- 多くの記事はcommitlint + huskyにより、開発者local環境で実行されるgit commitのチェック方法を紹介している
- 複数の開発者がいるプロジェクトでは、以下のデメリットやリスクがある
  - 各開発者のlocal環境に共通のgit hookを導入させる手間が掛かる
  - 開発者localにgit hookを入れ忘れたまま開発される可能性がある
  - git hookが導入されていても`git commit --no-verify`で無視することが出来てしまう
- 以上より、gitlab server側でチェックするのが望ましいと判断した

## gitlab server側で実現することのデメリット
- git hookのpre-receiveを使うため、チェックのタイミングは開発者がbranchをpushした時になる(少し遅い)
- 理想的には開発者がlocal環境でgit commitする度にチェックしたいが、これにはlocal側git hookであるpre-commitが必要なので、開発者が各自でlocal環境にhusky + commitlintを導入する必要がある
  - husky + commitlintはnpmが必要なので、開発者のlocal環境

## 前提となるディレクトリ構成
```
zakuro0w0@MSI:/mnt/d/programs/docker/gitlab$ tree .
.
├── Dockerfile_gitlab
├── commitlint.config.js
├── default.conf
├── docker-compose.yml
├── pre-receive
└── swagger_default.conf
```

## 各種ファイルの準備

### pre-receive
```ruby:pre-receive
#!/opt/gitlab/embedded/bin/ruby

## このファイルについて
## gitlabサーバ側で実行されるgit hook script
## pre-receiveはlocalの開発者がremoteへpushした際にサーバ側で実行され、
## 今回はcommit messageがconventional commitに準拠しているか否かをチェックする役割を持つ

## exitに渡す終了ステータスにより、gitlabへのpushの合否が決まる
## 終了ステータス0 : pushは合格となり、正常に実行される
## 終了ステータス0以外 : pushは不合格となり、拒否される

## 引数から以下を取り出す
## rev_old : pushで変更される前の最新commit
## rev_new : pushで変更された後の最新commit
## ref : branch
rev_old, rev_new, ref = STDIN.read.split(" ")

## 引数の情報を表示
## pre-receiveが標準出力したものはpushを実行したlocalでも表示される
#puts "rev_old : #{rev_old}"
#puts "rev_new : #{rev_new}"
#puts "ref : #{ref}"

line = "-------------------------------------------------"

puts line
puts `date`

puts line
puts "## 今回pushされたcommitの一覧"
puts `git log --oneline #{rev_old}..#{rev_new}`

puts line
puts "## commit messageに対するcommitlintの結果"
## 予めgitlabサーバにnpmでinstallしたcommitlintを利用し、conventional commit準拠チェックを行う
result = `npx commitlint --from #{rev_old} --to #{rev_new} --verbose`
puts result

## commitlint実行結果に"found N problems"(N > 0)が1行でも含まれていたら不合格とする
## grepコマンド内の"[1-9]|[0-9]{2,}"は1~9で構成される1桁の数字 or 0~9で構成される2桁以上の数字 を指す正規表現
problemCount = `echo "#{result}" | grep -E "found [1-9]|[0-9]{2,} problems" -c`

## 終了ステータスを指定してpre-receiveを終了する
exit problemCount.to_i
```

### commitlint.config.js
```js:commitlint.config.js
## このファイルについて
## gitlabにinstallしたcommitlintモジュールの設定ファイル
## pushされたcommitメッセージがconventional commitに準拠しているかをチェックする
module.exports = {extends: ['@commitlint/config-conventional']}
```

### Dockerfile_gitlab
```:Dockerfile_gitlab
## このファイルについて
## gitlabコンテナを構築するためのDockerfile
## 素のgitlab imageにconventional commitを強制するための追加installを行う
FROM gitlab/gitlab-ce:latest

## node.jsとnpmをinstallする
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && apt-get install -y nodejs

## npmでcommitlintをinstallする
## globalにinstallすることで、どのリポジトリからでもnpx commitlintできるようにする
## commitlint.config.jsのintallはdocker-compose.ymlのvolumeにて行う
WORKDIR /var/opt/gitlab
RUN npm init -y && npm install -g --save-dev @commitlint/cli @commitlint/config-conventional

## gitlab内の全リポジトリ向けglobal git hookのディレクトリを作成する
## pre-receive hook本体のinstallはdocker-compose.ymlのvolumeにて行う
WORKDIR /opt/gitlab/embedded/service/gitlab-shell/hooks
RUN pwd && mkdir pre-receive.d
```

### docker-compose.yml
```yml:docker-compose.yml
version: '3.7'
services:
    gitlab:
        ## Dockerfileで構築したimageを使う
        build:
            context: .
            dockerfile: Dockerfile_gitlab
        restart: always
        container_name: mygitlab.com
        hostname: 'mygitlab.com'
        environment:
                GITLAB_OMNIBUS_CONFIG: |
                        nginx['custom_gitlab_server_config'] = "location /-/plantuml/ { \n    proxy_cache off; \n    proxy_pass  http://plantuml:8080/; \n}\n"
        ports:
            - "10080:80"
        volumes:
            ## 予め作っておいたdocker volumeをmountする
            ## volumeにmountした部分はコンテナがremoveされても残る
            - gitlab_etc:/etc/gitlab
            - gitlab_log:/var/log/gitlab
            - gitlab_opt:/var/opt/gitlab
            ## pre-receive scriptをgitlab全リポジトリ共通のgit hookとして配置する
            - ./pre-receive:/opt/gitlab/embedded/service/gitlab-shell/hooks/pre-receive.d/pre-receive
            ## commitlint設定ファイルを配置する
            - ./commitlint.config.js:/var/opt/gitlab/commitlint.config.js
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
    nginx-proxy:
        image: nginx:latest
        container_name: myproxy
        ports:
            - "80:80"
        volumes:
            - ./default.conf:/etc/nginx/conf.d/default.conf
    nexus:
        image: sonatype/nexus3
        hostname: mynexus.com
        container_name: mynexus.com
        ports:
            - "8081:8081"
    swagger:
        image: swaggerapi/swagger-ui
        hostname: myswagger
        container_name: myswagger
        ports:
            - "8080:8080"
        volumes:
            - ./swagger_default.conf:/etc/nginx/conf.d/default.conf
## 以下のvolumeは`docker volume create {volume名}`で予め作っておくこと
volumes:
    gitlab_etc:
        external: true
    gitlab_opt:
        external: true
    gitlab_log:
        external: true
```

## Dockerfileからビルド後、コンテナを起動
```
docker-compose up -d --build
```

## commitlintの動作確認

### gitlabサーバ側で確認
```
docker exec -it mygitlab.com bash
```

```
npx commitlint
```

### 開発者local側で確認
- `http://mygitlab.com`にアクセスし、rootアカウントの作成
- group, projectを作成(ここでは仮にsandbox/githooktest.gitとする)

```
git clone http://mygitlab.com/sandbox/githooktest.git
```

#### 失敗するメッセージで空commit
```
git commit -m "aaa:bbb" --allow-empty
```

```
git push origin master
```

```
zakuro0w0@MSI:/mnt/d/programs/vscode/projects/githooktest$ git commit -m "aaa:bbb" --allow-empty
[master 89f30bc] aaa:bbb
zakuro0w0@MSI:/mnt/d/programs/vscode/projects/githooktest$ git push origin master
Username for 'http://mygitlab.com': root
Password for 'http://root@mygitlab.com':
Counting objects: 1, done.
Writing objects: 100% (1/1), 182 bytes | 182.00 KiB/s, done.
Total 1 (delta 0), reused 0 (delta 0)
remote: -------------------------------------------------
remote: Tue May 12 04:23:26 UTC 2020
remote: -------------------------------------------------
remote: ## 今回pushされたcommitの一覧
remote: 89f30bc aaa:bbb
remote: -------------------------------------------------
remote: ## commit messageに対するcommitlintの結果
remote: ⧗   input: aaa:bbb
remote: ✖   subject may not be empty [subject-empty]
remote: ✖   type may not be empty [type-empty]
remote:
remote: ✖   found 2 problems, 0 warnings
remote: ⓘ   Get help: https://github.com/conventional-changelog/commitlint/#what-is-commitlint
remote:
To http://mygitlab.com/sandbox/githooktest.git
 ! [remote rejected] master -> master (pre-receive hook declined)
error: failed to push some refs to 'http://mygitlab.com/sandbox/githooktest.git'
```

#### 成功するメッセージで空commit

```
git commit -m "fix: title" --allow-empty
```

```
git push origin master
```

```
zakuro0w0@MSI:/mnt/d/programs/vscode/projects/githooktest$ git commit -m "fix: title" --allow-empty
[master 659ba81] fix: title
zakuro0w0@MSI:/mnt/d/programs/vscode/projects/githooktest$ git push origin master
Username for 'http://mygitlab.com': root
Password for 'http://root@mygitlab.com':
Counting objects: 1, done.
Writing objects: 100% (1/1), 184 bytes | 184.00 KiB/s, done.
Total 1 (delta 0), reused 0 (delta 0)
remote: -------------------------------------------------
remote: Tue May 12 04:09:26 UTC 2020
remote: -------------------------------------------------
remote: ## 今回pushされたcommitの一覧
remote: 659ba81 fix: title
remote: -------------------------------------------------
remote: ## commit messageに対するcommitlintの結果
remote: ⧗   input: fix: title
remote: ✔   found 0 problems, 0 warnings
To http://mygitlab.com/sandbox/githooktest.git
   af47fc4..659ba81  master -> master
```
