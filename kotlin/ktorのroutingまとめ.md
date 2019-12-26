# ktor server routing

## 生成済みWebServerに新たなroutingを追加する
- ~~embeddedServer()で作成したものをApplicationEngineとして渡せば.application.routing{}から新たなURIパスの設定が可能~~
	- embeddedServer()が返したApplicationEngineをstart()せずにroutingを追加しようとすると例外が発生するため、以下の例のようにembeddedServer()構築中にroutingを追加する必要がある
	- URIパス被りの場合は後勝ちという記事があったので注意が必要

```kotlin
fun test(){
	embeddedServer(Netty, port = 8080){
		routing{
			add(this)
		}
	}.start()
}

fun add(routing: Routing) = routing{
	route("/app/myapp1"){
		post{
			// "/app/myapp1"へのPOSTが来た時の処理
		}
		get("/status"){
			// "/app/myapp1/status"へのGETが来た時の処理
		}
	}
}
```