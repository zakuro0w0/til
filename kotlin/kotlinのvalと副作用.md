# kotlinのvalと副作用
- 関数の引数は全てvalなので変更できない
- 変更できない == 再代入できない
- 副作用のある関数の呼び出し自体はOK

```kotlin
class Hoge(var x: Int){
    fun increment(){
		// 副作用!!
        x++
    }
}

fun test(hoge: Hoge){
	// hoge自体の再代入はNGだが、副作用のある関数呼び出しはOK
    hoge.increment()
}

fun main(args: Array<String>) {
    val hoge = Hoge(10)
    test(hoge)
    println(hoge.x) // hoge.x == 11
}
```