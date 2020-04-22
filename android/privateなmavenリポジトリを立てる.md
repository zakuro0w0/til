# privateなmavenリポジトリを立てる

## 背景
- androidを使った製品開発プロジェクトにて、リポジトリを複数に分割した運用をしたい
- あるリポジトリで作るapkが、他のリポジトリのjar/aarに依存する場合がある
- jar/aarはインターネット上のmaven central等のpublicリポジトリには置きたくない

## やりたいこと
- 社内の閉じたネットワーク内にprivateなmavenリポジトリを立てたい
- jar/aarを作るリポジトリの成果物はこのprivate mavenリポジトリで管理したい
- 開発者ローカルのAndroidStudioでは、build.gradleに記述したprivate mavenリポジトリURL経由でjar/aarを取得したい
    - もちろん、jar/aarのバージョン指定も出来るように
- 構成管理のCIプロセスにて、ビルドしたartifact(jar/aar)をprivate mavenリポジトリに登録したい

## もしprivate mavenリポジトリが無かったら...
- jar/aarに依存するapkをビルドする際、逐一最新のjar/aarバイナリのコピーを入手しなければならない

## 導入~利用までの手順

### 1. nexus on dockerの起動
- sonatype製のバイナリリポジトリマネージャである[nexus](https://hub.docker.com/r/sonatype/nexus3)を使ってみる
- 競合としてよく比較されるのはjflog製のartifactory
    - DockerHubにてartifactory公式のdocker imageが見つけられなかったのでひとまずnexusを試す
- これらのサービスを使わず、[mavenの公式image](https://hub.docker.com/_/maven)を使う方法もある

#### 1.1. docker-compose.yml
- gitlab等、他に連携したいコンテナがあればそちらのdocker-compose.ymlのservicesにnexusを追加する
```yaml
version: '3.7'
services:
    nexus:
        image: sonatype/nexus3
        hostname: mynexus.com
        container_name: mynexus
        ports:
            - "8081:8081"
```

#### 1.2. nexusコンテナの起動
```
docker-compose up -d
```

#### 1.3. nexusへの接続確認
- webブラウザにて"http://localhost:8081"を開き、以下のようなページが表示されればnexusの起動はOK

![](./attachments/nexus_home.png)

#### 1.4. nexusのadminユーザパスワード

- nexus home画面の右上Sign in押下でadminパスワードの入力を求められる
    - nexusコンテナの/nexus-data/admin.passwordファイルに書いてある文字列がパスワードになる
![](./attachments/nexus_admin_password.png)

- docker-compose.ymlと同じディレクトリで以下を実行し、nexusコンテナに入る
```
docker exec -it mynexus bash
```

- adminパスワードを確認し、sign inの認証入力する
```
bash-4.4$ cat /nexus-data/admin.password 
5d19b8d9-2872-436e-8495-d855b7b46173
```

- この後、新しいadminパスワードの入力を求められる

![](./attachments/admin_password.png)

- anonymousユーザからのアクセスをどうするか聞かれる
    - 今回はenableとした

![](./attachments/anonymous_access.png)

#### 1.5. nexusのdeployment policyについて
- 各リポジトリはdeployment policyを持っており、artifact登録時の挙動を設定できる
- maven-release
    - デフォルト設定は`Disable redeploy`であるため、同じversion値での再登録は失敗するようになっている
    - 先に誰かがversion='1.0.0'で登録すると、再度version='1.0.0'で登録できない
- maven-snapshot
    - デフォルト設定は`Allow redploy`であるため、同じversion値での再登録が可能となっている
    - version='1.0.0-SNAPSHOT'で何度でも再登録できる

### 2. artifact登録用nexusアカウント作成
#### 2.1. deploy専用Roleの作成

![](./attachments/create_nexus_role_01.png)

- 特権にはadminとviewがあり、uploadだけならviewにするべき
- maven-publicへのbrowseとreadは無くてもuploadできる
    - このRoleを適用したユーザでnexusにログインした時、maven-publicも閲覧できるようにしておく

![](./attachments/create_nexus_role_02.png)

#### 2.2. deploy専用Userの作成

![](./attachments/create_nexus_user_01.png)

![](./attachments/create_nexus_user_02.png)


### 3. build.gradleからartifact登録
#### 3.1. mavenリポジトリとしてのURL確認
- nexusでRepositoriesを開き、以下のリポジトリがあることを確認する
    - maven-public
    - maven-releases
    - maven-snapshots
- 上記のリポジトリにjar/aarを登録しておき、build.gradleにてリポジトリURLを指定することになる

![](./attachments/repositories.png)

- 例えばmaven-publicを選択すると、リポジトリの情報が表示される
    - URLは"http://localhost:8081/repository/maven-public/"となる

![](./attachments/repository_url.png)

#### 3.2. AndroidStudioのプロジェクト構成(apk等に依存されるjar/aarを作る側)
- 以下のようなプロジェクト構成と仮定する
    - androidlibモジュールはandroidlib.aarを作る
```
project/
├── androidlib
│   └── build.gradle
├── build.gradle
└── maven.gradle
```
#### 3.3. project/maven.gradle

```
apply plugin: 'maven'

## nexusコンテナのURL
ext.maven_url = 'http://localhost:8081/repository'

## このmaven.gradleをapplyで取り込んだmoduleにて、
## implementationでnexusからpackageを取得できるようにするための定義
repositories {
    maven{
        url "${maven_url}/maven-public/"
    }
}

## `gradlew uploadArchives`コマンドで実行可能になるgradleタスクの定義
## maven.gradleをapplyしたmoduleの成果物(jar/aar)を指定のリポジトリに登録する
uploadArchives {
    repositories {
        mavenDeployer {
            ## 正式版を登録するreleaseリポジトリ
            repository(url: "${maven_url}/maven-releases") {
                ## nexusのユーザ認証が必要
                authentication(userName: 'deployer', password: 'xxxxx')
            }
            ## 開発中の成果物を登録するsnapshotリポジトリ
            snapshotRepository(url: "${maven_url}/maven-snapshots") {
                ## nexusのユーザ認証が必要
                authentication(userName: 'deployer', password: 'xxxxx')
            }
        }
    }
}
```

#### 3.4. project/androidlib/build.gradle

```
## 別途定義したmaven.gradleを取り込む
apply from: rootProject.file('maven.gradle')

## モジュール成果物(jar/aar)の所属groupを定義する
## jar/aarに依存する利用者はここで定義したgroupをimplementationで指定することになる
## 命名のルールは特にないが、androidのpackageと一致させておくと分かりやすいと思われる
group = 'com.nexus.test.example'

## implementationで指定する必要のあるモジュール成果物のバージョン
## version値の決め方については[バージョンの種類と使い分け](https://kengotoda.gitbooks.io/what-is-maven/deploy/snapshot-and-stable.html)を参照
## {major}.{minor}.{patch} が基本で、後ろに"-SNAPSHOT"を付けるとreleaseではなくsnapshotリポジトリに登録される
## release/snapshotどちらに登録してもmaven-publicからは見える
version = '1.0.0'
```

#### 3.5. artifactをmavenリポジトリにupload
- AndroidStudioのTerminalにて以下のコマンドを実行する
    - 通常、mavenへのuploadはサーバ側のCIプロセスが行うので、開発者が実行することは無い(というかしてはならない)

```
gradlew uploadArchives
```

#### 3.6. mavenリポジトリに登録した成果物をnexusで確認する

![](./attachments/upload_artifact.png)

### 4. 登録したartifactをnexus経由で取得する

#### 4.1. AndroidStudioのプロジェクト構成(jar/aarに依存するapk側)

```
project/
├── app
│   └── build.gradle
├── build.gradle
└── maven.gradle
```
#### 4.2. project/app/build.gradle
- nexusのBrowseにてimplementationするためのコードを確認できる
    - 基本的には`implementation "{group}:{module}:{version}"`でOK
    - 開発中のバージョンが欲しい場合はversionを`1.0.0-SNAPSHOT`等にする

![](./attachments/implementation_url.png)

```
apply from: rootProject.file('maven.gradle')
dependencies {
    implementation("com.nexus.test.example:androidlib:1.0.0")
}
```

#### 4.3. gradleの同期を実行
- AndroidStudioにてgradle同期を実行すれば指定したnexusのURLからimplementationで指定したandroidlib.aarのver1.0.0を入手できる
- 同期に失敗する場合はURLやimplementationの記述にミスが無いか確認すること