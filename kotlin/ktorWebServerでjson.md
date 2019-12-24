# ktor WebServerでjsonを扱う
- [Ktorはどう使う？ - タケハタのブログ](https://blog.takehata-engineer.com/entry/how-about-using-ktor)

## 1. module::build.gradle
```
dependencies{
	implementation "io.ktor:ktor-jackson:$ktor_version"
}
```

## 2. WebServer生成時にjsonをinstall
```kotlin
embeddedServer(Jetty, port=8080){
	install(ContentNegotiation){
		jackson{
			// json関連の設定はここに書く
		}
	}
}
```

## 3. routing設定の中でjsonを扱う
- post()のlocalで定義したdataクラスだとjson文字列をクラスにdeserializeできないので注意
```kotlin
data class Request(val id: Int)
data class Response(val id: Int, val name: String)

post("/json"){
	// HTTPリクエストのbodyに記述されたjsonをRequestクラスとして取り出す
    val request = call.receive<Request>()
    val response = Response(request.id, "ktor")
	// レスポンスとしてResponseクラスをjsonとして返す
    call.respond(response)
}
```