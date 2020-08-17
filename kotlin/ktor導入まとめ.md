# ktor WebServerライブラリ導入まとめ
---
## 概要
- JetBrains製、kotlinで実装されたWebServerライブラリ
- Android等でWebServerを立てるために使うフレームワーク
	- 比較対象になるのはSpringやSpark等
- 公式
	- [Ktor - asynchronous Web framework for Kotlin](https://ktor.io)
	- [GitHub - ktorio/ktor: Framework for quickly creating connected applications in Kotlin with minimal effort](https://github.com/ktorio/ktor)


## 導入
### build.gradle
- gradleに追記してsync >> 色々必要なpackageがdownloadされる

#### project/build.gradle
```groovy
buildscript {
    ext.ktor_version = '1.2.5'
    ext.coroutines_version = '1.3.2'
	//...
}
```

#### module/build.gradle
```groovy
android{
	//...
	packagingOptions {
        exclude 'META-INF/*'
    }
	// ktorサーバ起動時のJettyのBootstrapMethodErrorを回避するために必要(CIO, Nettyの時は不要)
	// https://qiita.com/kk2170/items/472dddb86b373f52f8e9
    compileOptions {
        targetCompatibility = "8"
        sourceCompatibility = "8"
    }
}
dependencies {
	//...
    // for ktor webserver
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-core:$coroutines_version"
    implementation "io.ktor:ktor-server-core:$ktor_version"
    implementation "io.ktor:ktor-server-cio:$ktor_version"
    implementation "io.ktor:ktor-server-netty:$ktor_version"
    implementation "io.ktor:ktor-server-jetty:$ktor_version"
    implementation "io.ktor:ktor-client-cio:$ktor_version"
    // for json
    implementation "io.ktor:ktor-jackson:$ktor_version"
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
#### WebServer.kt
```kotlin
package com.example.ktorsample

import io.ktor.application.call
import io.ktor.application.install
import io.ktor.features.ContentNegotiation
import io.ktor.jackson.jackson
import io.ktor.response.respond
import io.ktor.routing.get
import io.ktor.routing.routing
import io.ktor.server.engine.embeddedServer
import java.util.concurrent.TimeUnit
import io.ktor.server.cio.CIO
import io.ktor.server.netty.Netty
import io.ktor.server.jetty.Jetty

class WebServer(){
    private val server by lazy{
		// サーバの種類(Netty/Jetty/CIO)を指定して起動、ポート番号は8080とする
		//embeddedServer(CIO, port = 8080){
		//embeddedServer(Netty, port = 8080){
        embeddedServer(Jetty, port = 8080){
            install(ContentNegotiation){
				// jsonを使えるように
                jackson{}
            }
			// URIのルーティング設定
            routing{
				// httpメソッド別にURIを定義できる
				// wildcard="*", tailcard="{...}"でパターンマッチも可能
                get("/root/api"){
					// GETメソッドで"/root/api"に来た時の処理を定義
					// レスポンスを返す
                    call.respond("this is response")
                }
            }
        }
    }

    fun start(){
        server.start()
    }

    fun stop(){
		// 明示的にサーバを止める場合はこれを呼び出す
		// 呼び出さずにActivityを終了させた場合でも、ポート番号が占有されたままになったりはしない
        server.stop(1, 5, TimeUnit.SECONDS)
    }
}
```

#### MainActivity.kt
```kotlin
package com.example.ktorsample

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

class MainActivity : AppCompatActivity() {
	// ktorサーバのクラスインスタンスを作成
    private val server = WebServer()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

		// ktorサーバを起動
        server.start()
    }
}
```

## 実際に呼び出す
- chromeブラウザ等でURL `http://localhost:8080/demo/resource`にアクセス
- ホストPCからRestClientを使う場合は以下のコマンドでリダイレクト設定が必要
```:ホストの18080をAVDの8080に転送
adb forward tcp:18080 tcp:8080
```
