# SYSTEM_ALERT_WINDOW permissionを許可する

## やりたいこと
- ユーザが設定画面で許可しなければ機能しないpermissionを、ユーザ操作無しで使えるようにしたい

## SYSTEM_ALERT_WINDOW permissionについて
- `Display over other apps`設定を可能にするためのpermission
- ↑の設定をONにすることで、android ServiceからView等をoverlay表示できる
- Settings >> Apps & notifications >> Special app access >> Display over other apps >> アプリ選択 >> Allow display over other appsのスライドボタンをONにすると許可できる
- `AndroidManifest.xml`に以下を記述することで、`Display over other apps`設定が可能となる

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

## SYSTEM_ALERT_WINDOW permissionのprotectionLevel確認
- 以下のコマンドで各種permissionのprotectionLevelを確認することができる

```shell
adb shell pm list permissions -f
```

- protectionLevelの詳細は以下で確認できる
    - [R.attr protectionLevel | Android Developers](https://developer.android.com/reference/android/R.attr?hl=ja#protectionLevel)

- `SYSTEM_ALERT_WINDOW`については`signature`, `development`, `appop`, `pre23`, `preinstalled`がOR条件で結合されている
    - いずれかのprotectionLevelの要件が満たされていれば暗黙に使える、ということになる
    - `signature`はかなり強力な保護で、apkへのplatform署名 && システムアプリ化 が必須となる
```
+ permission:android.permission.SYSTEM_ALERT_WINDOW
  package:android
  label:This app can appear on top of other apps
  description:This app can appear on top of other apps or other parts of the screen. This may interfere with normal app usage and change the way that other apps appear.
  protectionLevel:signature|development|appop|pre23|preinstalled
```

> development
> 	Additional flag from base permission type: this permission can also (optionally) be granted to development applications.
> 	基本権限タイプからの追加フラグ：この権限は、（オプションで）開発アプリケーションにも付与できます。

> appop
> Additional flag from base permission type: this permission is closely associated with an app op for controlling access.
> 基本権限タイプからの追加フラグ：この権限は、アクセスを制御するためのアプリ操作と密接に関連しています。

> preinstalled
> Additional flag from base permission type: this permission can be automatically granted any application pre-installed on the system image (not just privileged apps).
> 基本権限タイプからの追加フラグ：この権限は、システムイメージにプリインストールされているすべてのアプリケーション（特権アプリだけでなく）に自動的に付与できます。

## 実現方法の候補

### 候補1. インストール済みアプリに対してコマンドで権限の付与・取り消し
- [Android Debug Bridge（adb）  \|  Android デベロッパー  |  Android Developers](https://developer.android.com/studio/command-line/adb?hl=ja#pm)
- pmコマンドのgrant/revokeで権限の付与・取り消しを制御できる
- インストール済みapkのパッケージ名と、制御したいpermission名を指定する
	- 実際にpermissionをAndroidManifest.xmlで宣言しているのがaarライブラリの場合、aarライブラリのパッケージ名ではなく、aarに依存しているapkのパッケージ名を指定する必要があるので注意

```
adb shell pm grant {packageName} {permissionName}
```

```
adb shell pm revoke {packageName} {permissionName}
```

- SYSTEM_ALERT_WINDOWをmanifestで宣言している`service.aar`に依存している`myapp.apk`に権限を付与したい場合は以下の通り
	- grantした後なら設定アプリでoverlayをenabledにしていなくてもoverlay表示可能
```shell
adb shell pm grant com.example.myapp android.permission.SYSTEM_ALERT_WINDOW
```

- 取り消しはrevokeで
```shell
adb shell pm revoke com.example.myapp android.permission.SYSTEM_ALERT_WINDOW
```

#### grant/revokeによる権限制御の課題
- インストールしてからコマンドを実行する必要がある点
	- CIの署名等で対応できた方が確実
- permission宣言しているパッケージではなく依存しているパッケージを対象としなければならない点
	- 依存関係を把握しきれていないと抜け漏れが出やすい

### 候補2. apkをシステムアプリ化する
- `protectionLevel=preinstalled`要件を満たすための方法
- 特権アプリでもOKと読めるので、`/system/priv-app/`配下にインストールするだけでpreinstalledの要件を満たすはず
- grantやoverlay設定無しで表示できることを確認した
- 詳細は[システムアプリのインストール方法](https://github.com/zakuro0w0/til/blob/master/android/dispatchKeyEventで拾えるキーイベントをシステムアプリから発行する.md#署名済みapkのシステムアプリとしての配置)を参照

```shell
emulator -list-avds
```

```shell
emulator -avd {AVD-name} -writable-system
```

```shell
adb root && adb remount && adb shell mkdir /system/priv-app/{apk-name}/ && adb push {apk-name}.apk /system/priv-app/{apk-name}/
```

### 候補3. apkにplatform署名を施す
- debugビルドした`myapp.apk`に対して、AOSP標準の鍵でplatform署名
- `adb install -t`でapkをインストール
- grantやoverlay設定は特に行わず、表示が出来ることを確認した
- platform署名だけでもOKなことが確認できた

#### platform署名で対応する場合の懸念点
- CIでビルドしたapkに署名しておけばapkをインストールするだけでOKなので簡単ではある
- が、apkが動作する環境(AVD/実機)に合わせた署名鍵が必要なので、環境毎にCIでビルドバリアントを用意しなければならない

