# conventional commitに基づくバイナリの自動バージョニング

## やりたいこと
- androidで開発するjar, aarといったバイナリのバージョニングを自動化したい
- gitlab-CIでビルドしたバイナリにバージョンを付与し、セルフホストしたmavenリポジトリにuploadするまでを自動化したい

## 前提条件
- mavenリポジトリのセルフホストは[privateなmavenリポジトリを立てる.md](./privateなmavenリポジトリを立てる.md)の手順で完了していること
    - ↑の手順で掲載しているmaven.gradleは使わないので注意
- gitのcommit messageはconventional commitに準拠していること
    - [conventional commitを強制するgitlabコンテナの構築.md](./conventional-commitを強制するgitlabコンテナの構築.md)
    - [開発者local環境にcommitlintをinstall.md](./開発者local環境にcommitlintをinstall.md)


## 今回使うもの
- [nebula-release-plugin](https://github.com/nebula-plugins/nebula-release-plugin)
    - gitlab-CIのscriptから各バイナリのbuild.gradleにversionを指定するために必要
- [nebula-publishing-plugin](https://github.com/nebula-plugins/nebula-publishing-plugin)
    - nebula.releaseで指定したversionを使ってmavenリポジトリにjar, aarをuploadするために必要
    - [maven-publish plugin](https://docs.gradle.org/current/userguide/publishing_maven.html#publishing_maven:snapshot_and_release_repositories)の記法も必要
- [GitLab CI/CDパイプラインからGitLabにコミット(Push)し直す方法](https://qiita.com/ynott/items/8cb3b3995cb41ca78437)
    - リポジトリ毎にSSH鍵とCI環境変数の設定が必要
- [standard-versionのcommit messageをカスタムする.md](./standard-versionのcommit-messageをカスタムする.md)
    - conventional commit messageを解釈して自動的にgit tagを切ってくれる
    - standard-version利用の前提となるnodejsの導入もリンク先ドキュメント参照

## CIで実現する処理の流れ
1. conventional commitに準拠したcommitがgitlabにpushされる
2. .gitlab-ci.yml定義のCIパイプラインが開始される
3. npx standard-versionにより、commit messageから自動的にバージョニングを行い、git tagを切る
4. standard-versionにより更新されたgit tag, CHANGELOG.md等をリポジトリにpushし直す
    - (このpushによりCIが実行されないよう、commit messageに"[ci skip]"を含める)
5. nebula.release-pluginにより、standard-versionが切ったgit tagをandroidのjar,aarバイナリに反映する
6. nebula.maven-publishにより、バージョンを指定したjar,aarバイナリをmavenリポジトリにuploadする

## リポジトリ内で準備するファイル

### ディレクトリ構成
```
repository/
├── androidlib  // aarを作るmodule
│   └── build.gradle
├── app         // apkを作るmodule
│   └── build.gradle
├── build.gradle
├── maven_publish.gradle
├── maven_publish.rb
├── version_bump.js
├── .versionrc.json
└── .gitlab-ci.yml
```

### {repository}/build.gradle
- nebula.releaseとnebula.maven-publishを使用する宣言を追加する
- 全てのmoduleに適用するため、{module}/build.gradleへのapply追記は不要

```groovy
plugins{
    id 'nebula.release' version '15.0.0'
    id 'nebula.maven-publish' version '14.0.0'
}
allprojects{
    apply plugin: 'nebula.release'
}
```

### {module}/build.gradle

```groovy
apply from: rootProject.file('maven_publish.gradle')
```

### {repository}/maven_publish.gradle

```groovy
apply plugin: "nebula.maven-publish"

// nexusコンテナのURL
// nexusのコンテナ名とホスト名は共にmymaven.comにしておくこと
// CIコンテナからのアクセスはnexusコンテナ名:{ポート番号}で行われる
// nexusコンテナのlistenポート番号を80には出来ないので、CIコンテナからは8081でアクセスするしかない
// これに合わせて開発者localからのアクセスもポート番号指定で行う必要がある
ext.maven_url = 'http://mymaven:8081/repository'

// このmaven.gradleをapplyで取り込んだmoduleにて、
// implementationでnexusからpackageを取得できるようにするための定義
repositories {
    maven{
        url "${maven_url}/maven-public/"
    }
}

// nebulaによるrelease(finalやdevSnapshot)時に必要な設定
nebulaRelease {
    // デフォルトではmaster, releaseといった名前のbranchのみnebula releaseが許容されている
    // 今回nebulaでreleaseをするbranchにはproductionもいるため、branch名を追加する
    // https://github.com/nebula-plugins/nebula-release-plugin#extension-provided
    addReleaseBranchPattern(/production/)
}

// artifactをmavenにuploadするgradleタスクの定義
// 自動生成されるgradleタスク名はpublishNebulaPublicationToMavenRepositoryとなる
afterEvaluate{
    publishing {
        publications {
            nebula(MavenPublication) {
                // https://stackoverflow.com/a/41929952
                pluginManager.withPlugin("com.android.application"){
                    // このgradleファイルをapplyしたモジュールがapkを作る場合
                    // https://developer.android.com/studio/build/maven-publish-plugin?hl=ja
                    from components.release_apk
                }
                pluginManager.withPlugin("com.android.library"){
                    // このgradleファイルをapplyしたモジュールがaarを作る場合
                    from components.release
                }
                repositories{
                    maven{
                        def releaseReposUrl = "${maven_url}/maven-releases"
                        // master branchの時はsnapshotバージョンをuploadさせたい
                        // nebula devSnapshotが作るバージョンと、nexusのsnapshotバージョンポリシーが合わない(バージョン末尾が-SNAPSHOTにならない)ため、
                        // バージョンポリシーがrelease相当のmaven-devsnapshotsリポジトリをnexus上に作ってある
                        def snapshotReposUrl = "${maven_url}/maven-devsnapshots"
                        // `nebula -Psnapshot devSnapshot publishNebulaPublicationToMavenRepository`のような形式で-Pに続けて指定した文字列がpropertyとして認識される
                        // `-Psnapshot`を付けてpublishした場合はmaven-devsnapshotsへuploadさせる
                        // maven-gradleのチュートリアルでは`-Prelease`を付けてhasProperty('release')でURLを切り替える例が紹介されているが、これはnebulaでは使えない
                        // nebulaは最初からreleaseプロパティを持っているため、`-Prelease`を付けていなくてもhasProperty('release')がtrueになっていしまい、意図したURLが選択されない
                        url = project.hasProperty('snapshot') ? snapshotReposUrl : releaseReposUrl
                        // maven_urlが指すmavenリポジトリのサインイン情報
                        // 開発者はこのusername + passwordでmavenリポジトリを閲覧できる
                        credentials{
                            username = 'deployer'
                            password = 'deployer'
                        }
                    }
                }
            }
        }
    }
}
```

### {repository}/maven_publish.rb
- .gitlab-ci.ymlから呼び出し、snapshotまたはreleaseとしてmavenにpublishする
  - snapshotバージョンをpublishする場合は`ruby ci-template/maven_publish.rb snapshot`
  - releaseバージョンをpublishする場合は`ruby ci-template/maven_publish.rb release`
- shellで書いても良い(でもrubyの方が書きやすかったのでrubyにした)
- .gitlab-ci.ymlにこの処理を書いても良いが、gitlabサーバ側にcommitlintが入ってる場合は"fix: hogehoge"のようなcommitコメントが必要になる
  - yml書式の都合上、文字列の中に": "のようなコロン＋スペースが入るとymlが壊れるため、conventional commit準拠のコメントはyml以外のファイルに書く必要がある

```ruby
## node.js + npm + standard-versionをinstall
`curl -sL "https://deb.nodesource.com/setup_10.x" | bash - && apt-get install -y nodejs`
puts `npm init -y && npm install standard-version`

## 引数としてreleaseまたはsnapshotを指定する
## release : 正式リリース(v1.2.0のような形式のtagを切る)
## snapshot : 開発中リリース(v1.2.0-SNAPSHOT.0のような形式のtagを切る)
releaseType = ARGV[0]

## nebulaに渡すオプション
## デフォルトは引数がreleaseだった場合で、最新のgit tagを使って正式リリースする
nebula_publish_option = "-Prelease.useLastTag=true final"

if(releaseType == "release")
    ## 引数がreleaseだった場合
    ## standard-versionによるcommit message解析 + git tag生成
    puts `npx standard-version`
    puts `cat CHANGELOG.md`

    if(!`git status`.include? "clean")
        ## git statusの結果がcleanでなく、ファイルの変更があった場合
        puts `git add CHANGELOG.md`
        ## CIからcommitする時、必ずコメントに"[ci skip]"を含めておく必要がある
        ## これが無いと無限にCIパイプラインが実行され続ける
        ## また、GitLabサーバ側commitlintの存在により、commitコメントには必ずコロン(:)が含まれるが、
        ## .gitlab-ci.ymlファイル内でこのgit commit...コマンドを記述するとコロンによりymlファイル書式が壊れてしまう
        ## よって、commitlintのある環境にcommitする場合は.gitlab-ci.ymlではないファイルにcommitコマンドを記述する必要がある
        puts `git commit -m "docs(release): [ci skip] update CHANGELOG.md"`
        ## standard-versionが更新したfile, git tagをリポジトリにpush
        puts `git push origin --tags && git push`
    end
elsif(releaseType == "snapshot")
    ## 引数がsnapshotだった場合はdevSnapshotとしてmavenに登録する
    ## nebula-releaseにはsnapshotタスクも用意されているが、
    ## snapshotタスクがバイナリに付与するバージョンは`v1.2.0-SNAPSHOT`のように、最新のgit tagからminor+1したものになる
    ## mavenリポジトリから目当てのバージョンを探す際、commit hashとの紐付けが分からないと困るだろうということで、
    ## snapshotタスクではなくdevSnapshotタスクを使うことにした
    ## 
    ## devSnapshotタスクはバージョンにcommit hashを付けてくれるが、
    ## mavenリポジトリとして採用したnexusコンテナのmaven-snapshotsリポジトリのバージョンポリシーは
    ## バージョン文字列の末尾が"-SNAPSHOT"であることを強要するため、maven-devsnaphotsをリリースポリシーで新規作成した
    nebula_publish_option = "-Psnapshot devSnapshot"
end

## finalタスクの前に一時ファイルを削除しておく
puts `rm -rf node_modules/`
puts `rm -rf public/`

## nebulaによるmavenリポジトリへのpublish
puts "command = ./gradlew #{nebula_publish_option} publishNebulaPublicationToMavenRepository"
puts `./gradlew #{nebula_publish_option} publishNebulaPublicationToMavenRepository`
```


### {repository}/version_bump.js
```js
// git tagから取らずともpackage.jsonから新しいversion値を取得できる
var version = require('./package.json').version
// gitlab CIをskipさせるため、commit messageに[ci skip]を追加する
console.log("chore(release): [ci skip] v" + version)
```

- 実行する場合はnodeにjsファイルを渡せばOK
```shell
node version_bump.js
```

- standard-versionはリポジトリ配下の.versionrc.jsonを参照する
	- precommit hookの出力がstandard-versionのgit commit messageとして利用される
### {repository}/.versionrc.json
```json
{
  "scripts": {
    "precommit": "node version_bump.js"
  }
}
```

### {repository}/.gitlab-ci.yml
- nebula.releaseが提供するgradleタスクfinalの注意点
    - 実行ディレクトリ配下にgitにcommitされていないファイルが1個でもあると失敗する
    - git管理下に無い一時ファイルでもNGなので、CIで生成したものは全て始末しておく必要がある
    - .gitlab-ci.ymlのtemplateではgradlewファイルに`chmod +x gradlew`で実行権限を付けているが、この実行権限の変更も未commit差分としてfinalがNGにしてしまう
    - リポジトリに登録してあるgradlewファイル自体を実行権限付きでgit管理に置く必要がある
- publish jobがextendsしている`.enable_git`について
    - 鍵を設定しつつssh agentを起動することでCIコンテナからpushを可能にしている
    - rubyファイル内に同じ処理を定義した場合、`eval "$(ssh-agent -s)"`が上手く動かなかった
    - shellに分割することも考えたが、同じshellファイル内でpushまで実行しないとダメだった
    - .gitlab-ci.ymlで実行しておくと、rubyファイル内からのpushも動いた

```yml
## https://hub.docker.com/r/jangrewe/gitlab-ci-android/ を使用
## android SDK周りのダウンロード済みimageを使うことでCIパイプラインの実行時間を短縮する
image: jangrewe/gitlab-ci-android

variables:
    ANDROID_COMPILE_SDK: "29"
    ANDROID_BUILD_TOOLS: "29.0.2"
    ANDROID_SDK_TOOLS: "4333796"
    ## CI対象となるモジュール配列を定義する
    MODULES: "myapp myandroidlibrary"

## 各jobの前に必ず実行される準備処理
before_script:
    - apt-get update --yes
    ## rubyスクリプトを実行するのでrubyのインストールも必要
    - apt-get install --yes wget tar unzip lib32stdc++6 lib32z1 ruby
    - export GRADLE_USER_HOME=$(pwd)/.gradle

## gradleをキャッシュすることでCIパイプライン実行時間を短縮する
cache:
    key: ${CI_PROJECT_ID}
    paths:
        - .gradle/

## jobはいずれかのstageに属する
## stageはここで定義した順に遷移する
stages:
    - .pre
    - build
    - test
    - deploy

## publish_xxx jobでgitコマンドを使えるようにするための準備処理
## .で始まるjobはtemplateとして他のjobから参照することができる
.enable_git:
    ## この処理を参照したjobはbefore_scriptが丸ごと上書きされる
    ## このファイルの上の方で定義したbefore_scriptの内容は実行されなくなるので、
    ## 仕方なく同じ内容をこちらにもコピペすることで対応した(もっとスマートに実現したい)
    before_script:
        - apt-get update --yes
        ## ssh gitが新たに必要
        - apt-get install --yes wget tar unzip lib32stdc++6 lib32z1 ruby ssh git
        - export GRADLE_USER_HOME=$(pwd)/.gradle
        - ssh -V
        - git --version
        - mkdir -p ~/.ssh
        - chmod 700 ~/.ssh
        - ssh-keyscan -H "$CI_SERVER_HOST" >> ~/.ssh/known_hosts
        - which ssh-agent || ( apk add --update openssh)
        - eval "$(ssh-agent -s)"
        ## リポジトリ設定 >> CI/CD >> VariablesでSSSH秘密鍵をSSH_PRIVATE_KEYという名前で登録しておく必要がある
        ## また、同時に公開鍵をリポジトリ設定 >> リポジトリ >> deploy keysにて登録しておく必要がある
        ## このSSH鍵の登録が無いとCIコンテナからgit pushできない
        - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
        - git config --global user.name "gitlab-ci"
        - git config --global user.email "gitlab-ci@example.com"
        - git remote set-url --push origin git@$CI_SERVER_HOST:/$CI_PROJECT_PATH.git
        - git checkout $CI_COMMIT_REF_NAME
        ## -ffオプションを付けないと余分なmerge commitが生まれてしまう
        ## snapshot publishが指すcommitもmerge commitになってしまうので、--ffを推奨
        - git pull --ff

build:
    stage: build
    script:
        - ./gradlew assembleDebug
        - ./gradlew assembleRelease
    artifacts:
        paths:
            - myapp/build/outputs/
            - myandroidlibrary/build/outputs/
    tags:
        - android_runner

publish_snapshot:
    extends: .enable_git
    stage: deploy
    script:
        - ruby ci-template/maven_publish.rb snapshot
    only:
        - master
    tags:
        - android_runner

publish_release:
    extends: .enable_git
    stage: deploy
    script:
        - ruby ci-template/maven_publish.rb release
    only:
        - production
    tags:
        - android_runner
```
