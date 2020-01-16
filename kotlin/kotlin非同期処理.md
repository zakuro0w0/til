# kotlin 非同期処理

## 非同期処理終了以外をトリガーとした待ち合わせ
- C++で言うとcondition_variableに相当する機能を実現したい
- asyncで起動した非同期処理の終了をawait()で待ち合わせは可能だが、プロセス間通信やHTTP通信の返事が来るまでblockしたい場合には適さない
- Channelはsend()とreceive()がランデブーした時にblockが解除されるため、非同期待ち合わせに使える

```kotlin
data class Ball(var hits: Int)

fun test() = runBlocking {
    val table = Channel<Ball>() // a shared table
    launch { player("ping", table) }
    launch { player("pong", table) }
    table.send(Ball(0)) // serve the ball
    delay(1000) // delay 1 second
    coroutineContext.cancelChildren() // game over, cancel them
}

suspend fun player(name: String, table: Channel<Ball>) {
    for (ball in table) { // receive the ball in a loop
        ball.hits++
        println("$name $ball")
        delay(300) // wait a bit
        table.send(ball) // send the ball back
    }
}
```

## kotlin channel receive timeout
- `Channel<T>.receive()`に待ち時間上限を付けたい
	- [Cancellation and Timeouts - Kotlin Programming Language](https://kotlinlang.org/docs/reference/coroutines/cancellation-and-timeouts.html)
	- kotlinx.coroutines.withTimeout(), withTimeoutOrNull()を使う
	- coroutineブロックのキャンセル全般で使えるらしい
	- withTimeoutOrNull()のようなsuspend関数を呼び出す関数を作るためには...
		- `suspend fun myFunc(){ withTimeout(1000L){...} }`
		- ↑のようにsuspendを付ければOK

```kotlin
val channel = Channel<Int>()
launch{
	try{
		// timeout時間(msec)を指定して時間制限付き処理を開始
		val result = withTimeout(1000L){
			// channel.send()されるまで待つ
			channel.receive()
		}
	}catch(e: TimeoutCancellationException){
		// timeout時には例外がthrowされる
		print(e)
	}
}
```

```kotlin
val channel = Channel<Int>()
launch{
	// timeout時間(msec)を指定して時間制限付き処理を開始
	val result = withTimeoutOrNull(1000L){
		// channel.send()されるまで待つ
		channel.receive()
	}
	if(result == null){
		// timeout発生
	}else{
		// channel.receive()の結果がresultに得られた
	}
}
```
