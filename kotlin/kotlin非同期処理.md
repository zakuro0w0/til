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