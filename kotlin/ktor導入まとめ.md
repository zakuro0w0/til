# ktor WebServerライブラリ導入まとめ
---
## 概要
- JetBrains製、kotlinで実装されたWebServerライブラリ
- Android等でWebServerを立てるために使うフレームワーク
	- 比較対象になるのはSpringやSpark等
- 公式
	- [Ktor - asynchronous Web framework for Kotlin](https://ktor.io)
	- [GitHub - ktorio/ktor: Framework for quickly creating connected applications in Kotlin with minimal effort](https://github.com/ktorio/ktor)

---
## 導入
### build.gradle
- gradleに追記してsync >> 色々必要なpackageがdownloadされる

```:project/build.gradle
buildscript {
    ext.ktor_version = '1.2.5'
    ext.coroutines_version = '1.3.2'
	//...
}
```

```:module/build.gradle
dependencies {
	//...
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-core:$coroutines_version$"
    implementation "io.ktor:ktor-server-core:$ktor_version"
    implementation "io.ktor:ktor-server-cio:$ktor_version"
    implementation "io.ktor:ktor-server-netty:$ktor_version"
    implementation "io.ktor:ktor-server-jetty:$ktor_version"
    implementation "io.ktor:ktor-client-cio:$ktor_version"
}
```

### AndroidManifest.xml
```xml
<manifest
	xmlns:android="http://schemas.android.com/apk/res/android" 
	package="com.example.myapp">
	<!-- network関連の権限許可が必要 -->
	<uses-permission android:name="android.permission.INTERNET" />
	<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
	<!-- 以下省略 -->
</manifest>
```

### 実装
```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
	setContentView(R.layout.activity_main)
	// サーバインスタンスをJetty実装で立てる、ポート番号8080でlistenする
	embeddedServer(Jetty, 8080){
		// URIのルーティング設定
		routing{
			// httpメソッド別にURIを定義できる
			// wildcard="*", tailcard="{...}"でパターンマッチも可能
			get("/demo/resource"){
				// GETメソッドで"/demo/resource"に来た時の処理を定義
				call.respondText("this is response")
			}
		}
	}.start()
}
```

---
## 実際に呼び出す
- chromeブラウザ等でURL `http://localhost:8080/demo/resource`にアクセス
- ホストPCからRestClientを使う場合は以下のコマンドでリダイレクト設定が必要
```:ホストの18080をAVDの8080に転送
adb forward tcp:18080 tcp:8080
```
