# enum

## 列挙子で分岐処理

```kotlin
enum class Type{
	A, B, C
}

fun test(type: Type){
	when(type){
		A -> { /**/ }
		B -> { /**/ }
		else ->{ /**/ }
	}
}
```

## コンストラクタで値を与える
- 列挙子と特定の型の値をenumだけでmappingできる
- C++だと`std::map<Type, int>`のようにmappingしていた部分で楽になる
- 単に定数値として宣言するだけの場合と異なるのは...
	- enum型として運搬が可能になる
	- 列挙子以外へのアクセスを制限できる

```kotlin
enum class Type(raw: Int){
	A(10),
	B(20),
	C(30)
}

fun test(type: Type){
	print("value=${type.raw}") // value=10
}
```

## enumの列挙子で繰り返し(+列挙子の名前文字列)
```kotlin
enum class Type{ A, B, C }

fun test(){
	Type.values().forEach{
		println(it.name) // "A B C"
	}
}
```

## 文字列から列挙子を得る

```kotlin
enum class Type{ A, B, C }

fun test(){
	Type.valueOf("A") // Type.A
	Type.valueOf("Z") // IllegalArgumentException
}
```

