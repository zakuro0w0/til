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
├── maven.gradle
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
    apply from: rootProject.file('maven.gradle')
}
```

### {repository}/maven.gradle
```groovy
apply plugin: "nebula.maven-publish"

// nexusコンテナのURL
// nexusのコンテナ名とホスト名は共にmymaven.comにしておくこと
// CIコンテナからのアクセスはnexusコンテナ名:{ポート番号}で行われる
// nexusコンテナのlistenポート番号を80には出来ないので、CIコンテナからは8081でアクセスするしかない
// これに合わせて開発者localからのアクセスもポート番号指定で行う必要がある
ext.maven_url = 'http://mymaven.com:8081/repository'

// このmaven.gradleをapplyで取り込んだmoduleにて、
// implementationでnexusからpackageを取得できるようにするための定義
repositories {
    maven{
        url "${maven_url}/maven-public/"
    }
}

// artifactをmavenにuploadするgradleタスクの定義
// 自動生成されるgradleタスク名はpublishNebulaPublicationToMavenRepositoryとなる
publishing {
    publications {
        nebula(MavenPublication) {
            repositories{
                maven{
                    def releaseReposUrl = "${maven_url}/maven-releases"
                    def snapshotReposUrl = "${maven_url}/maven-snapshots"
                    url = version.endsWith('SNAPSHOT')? snapshotReposUrl : releaseReposUrl
                    credentials{
                        username = 'admin'
                        password = 'admin'
                    }
                }
            }
        }
    }
}
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

```yml
image: jangrewe/gitlab-ci-android

variables:
    ANDROID_COMPILE_SDK: "29"
    ANDROID_BUILD_TOOLS: "29.0.2"
    ANDROID_SDK_TOOLS: "4333796"

before_script:
    - apt-get update --yes
    - apt-get install --yes wget tar unzip lib32stdc++6 lib32z1
    - export GRADLE_USER_HOME=$(pwd)/.gradle
    ## CIコンテナからgit操作できるようにする
    - apt-get install -y ssh git
    - ssh -V
    - git --version
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - ssh-keyscan -H "$CI_SERVER_HOST" >> ~/.ssh/known_hosts
    - 'which ssh-agent || ( apk add --update openssh)'
    - eval "$(ssh-agent -s)"
    - echo "$SSH_PRIVATE_KEY" | ssh-add - > /dev/null
    - git config --global user.name "gitlab-ci"
    - git config --global user.email "gitlab-ci@example.com"
    - git remote set-url --push origin git@CI_SERVER_HOST:$CI_PROJECT_PATH.git
    - git checkout $CI_COMMIT_REF_NAME
    - git pull
    ## node.js + npm + standard-versionをinstall
    - curl -sL "https://deb.nodesource.com/setup_10.x" | bash - && apt-get install -y nodejs
    - npm init -y && npm install standard-version

cache:
    key: ${CI_PROJECT_ID}
    paths:
        - .gradle/

release:
    stage: deploy
    script:
        ## standard-versionによるcommit message解析 + git tag生成
        - npx standard-version
        - ret=$(git status | sed -ne 's|.*\(clean\)|\1|p')
        - if [ -z $ret ];then
        ## standard-versionが更新したfile, git tagをリポジトリにpush
        -   git push origin --tags
        - fi
        ## finalタスクの前に一時ファイルを削除しておく
        - rm -rf node_modules/
        ## standard-versionが生成した最新のgit tagをversionとして使う指定をしつつ、artifactをmavenリポジトリにuploadさせる
        - ./gradlew -Prelease.useLastTag=true final publishNebulaPublicationToMavenRepository
    tags:
        - android_runner
```
