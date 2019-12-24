# json on kotlin
- kotlinでjsonを扱う方法をまとめる
- 今回はgsonを使う
- 他にもjackson, klaxon, kotshi(moshi)がある
- [【Java】GsonとJacksonのJSONパース処理速度を比べてみる - まったり技術ブログ](https://blog.motikan2010.com/entry/2018/01/20/GsonとJacksonのパース処理速度を比べてみる)
- 基本的にはどのライブラリもjson定義に沿ったdata classを用意する必要がありそう
- C++のjson11のように`auto value = json["keyName"];`みたいな取得はできなさそう

## packageの導入
- module::build.gradleに以下を記述する
- gson_versionは[Releases · google/gson · GitHub](https://github.com/google/gson/releases)を見て最新ぽいものを選ぶ

```
dependencies{
	implementation "com.google.code.gson:gson:$gson_version"
}
```

## json文字列からクラスインスタンスへ

```kotlin
import com.google.gson.Gson
data class MyData(val status: Int)

fun test(){
	val jsonString = "{ \"status\" : 10 }"
	val myData = Gson().fromJson(jsonString, MyData::class.java)
	print("status=${myData.status}") // status=10
}
```


## クラスインスタンスをjson文字列へ

```kotlin
import com.google.gson.Gson
data class MyData(val status: Int)

fun test(){
	val jsonString = Gson().toJson(MyData(10))
	print(jsonString) // { "status" : 10 }
}
```