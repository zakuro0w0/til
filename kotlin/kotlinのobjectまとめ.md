# objectキーワードの使い方

## object式
- Anyまたは任意の型を継承した匿名型のインスタンスを生成する
- わざわざクラスにするまでもないような定義をobject式で済ませることが出来る
- 匿名型ということは名前を指定してインスタンスが作れないので、unitTestでテストコードを書くのに困る気がする

```kotlin
// Any型を継承した匿名objectを作る
// object{}と宣言した場合は暗黙にAny型を継承する
val anyObject = object{
	// プロパティも定義できる
	val x = 99
	// 関数も定義できる
	fun print(){
		println(x)
	}
}
// object式のインスタンスを通して呼び出す
anyObject.print()
```

```kotlin
// ユーザ定義interface
interface MyInterface{
	fun foo(): Int
}
// MyInterfaceを継承した匿名objectを作る
// ユーザ定義interfaceに限らず具象型を継承させることも可能
val myObj = object : MyInterface{
	override fun foo() = 999
}
// object式のインスタンスを通して呼び出す
println(myObj.foo())
```

## object宣言
- singletonなインスタンスを定義出来る
- コンストラクタを定義出来ないため、外部からの引数が初期化に必要なクラスをobject宣言することは出来ない

```kotlin
// static同等なので、コンストラクタは持てない
object MyObject{
	// プロパティも定義できる
	val x: Int = 999
	// 関数も定義できる
	fun print() = println(x)
}
// 呼び出しは型名から直接行う
MyObject.print()
```

## companion object
- classの中でstaticなメンバを定義出来る
- 古い記事だとcompanion objectではなくclass objectとして紹介している

```kotlin
class MyClass{
	private val z = 777
	// companion object内はstatic
	companion object{
		val x: Int = 999
		fun print() = println(x)
		// objectと同じくstatic同等なので、
		// インスタンスメンバは参照できない
		// fun print() = println(z)
	}
}
// companionとして宣言したobjectは、
// 持ち主のクラスのメンバであるかのように呼び出せる
MyClass.print()
```

## 外部からの引数が初期化に必要なsingleton??
- 2回目のcreate()で渡す入力は無視され、1回目のcreate()で作ったインスタンスが返される
- 引数が必要なsingletonは何かおかしい気がする

```kotlin
// コンストラクタはprivateとし、Fooインスタンスを直接構築できないようにする
class Foo private constructor(val x: Int){
    companion object {
		// singletonなインスタンス本体
        private var instance: Foo? = null
		// 利用者はcreate()経由でのみFooを取得できる
        fun create(z: Int): Foo{
            instance?: run{
                instance = Foo(z)
            }
            return instance!!
        }
    }
}

val foo = Foo.create(999)
```

