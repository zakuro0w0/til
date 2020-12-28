# android10以降の権限取得とActivity呼び出し結果の取得

## android 10以降の権限周り
- [アプリの権限のリクエスト  \|  Android デベロッパー  |  Android Developers](https://developer.android.com/training/permissions/requesting?hl=ja)
	- android10以降の権限リクエストについて説明がある
- [Activity  \|  Android デベロッパー  |  Android Developers](https://developer.android.com/jetpack/androidx/releases/activity#1.0.0)
	- 依存するactivity-ktxライブラリのバージョンはここで確認する
- [ActivityResultContractsの仕組みを調べてみる - Qiita](https://qiita.com/ryo_mm2d/items/32899f0a1e8c676b470c)
	- Before/Afterで分かりやすかった
- [startActivityForResult / requestPermissions が deprecated になる話 - Qiita](https://qiita.com/m-coder/items/97a3ce16276334be84aa)


### {module}/build.gradle
```groovy:build.gradle
implementation 'androidx.appcompat:appcompat:1.2.0'
implementation 'androidx.activity:activity-ktx:1.2.0-beta01'
```

### 権限リクエストsample
```kotlin
registerForActivityResult(ActivityResultContracts.RequestPermission()){
    if(it){
        println("permission granted!!!!!!!!!!!")
    }else{
        println("permission is not granted...")
    }
}.launch(WRITE_EXTERNAL_STORAGE)
```

### Activity呼び出し結果の取得sample
- [アクティビティからの結果の取得 | AndroidDeveloper](https://developer.android.com/training/basics/intents/result)

```kotlin
registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
    // 呼び出し先のActivityを閉じた時に呼び出されるコールバック
    if(it.resultCode == Activity.RESULT_OK) {
        // RESULT_OK時の処理
        val intent = it.data
        intent?.getStringExtra("result_key")
    }
}.launch(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
```

### 注意点
- registerForActivityResult()はActivityの中から呼び出す
- Settings.ACTION_MANAGE_OVERLAY_PERMISSIONはintentのactionに相当する
    - 所謂AndroidManifest.xmlの`<uses-permission>`に記述するpermissionとは異なる
    - なので`Manifest.permission.`と打ってもoverlay関連のpermissionは出てこない
    - このintentでdisplay overlayの許可を設定する画面が起動する
    - Uriに指定したpackageのアプリが設定の対象となるっぽい


