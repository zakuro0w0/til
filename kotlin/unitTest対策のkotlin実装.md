# unitTest対策のkotlin実装
- junitでunitTestを書くに当たって注意した方が良いトピックをまとめる

## カバレッジ測定ツールjacocoの仕様を知っておく
- jacocoはAndroidStudioに標準で搭載されている
- jacocoはJavaの時代から使われており、kotlinにも対応している
- しかし、jacocoがカバレッジを測定するのはkotlinコードではなく、kotlinコードから生成したjavaコードであることに注意が必要
- kotlinコード上では分岐を全て網羅していても、javaコードではそうでない場合が多い
- 真面目な開発者はAndroidStudioでkotlinバイトコードを逆コンパイルし、javaコードを見てカバレッジを何とか網羅しようとする
    - が、それではjacocoに振り回されてしまうので、ある程度の割り切りが必要になる
- 2021.02時点では他にカバレッジツールの選択肢が無い状態
    - IntelijIDEAのカバレッジランナーはCLIに対応しておらず、CIで使えない

## メンバの型は極力non-nullにするべき
- 後述するif-elseのscope関数にも関わるケース
- メンバのby lazyによる初期化の結果をnullableとし、nullだった場合はエラー処理を行うような実装
- by lazyによる初期化 + nullable型 という組み合わせがテストを複雑にしてしまう

```kotlin
class MainActivity : AppCompatActivity() {
    private val listener: IEventListener? by lazy {
        // listenerを初期化する
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        // listenerへの最初のアクセスでby lazyの中の初期化が実行される
        listener?.also {
            // listenerを使って何かする
            listener.doSomething()
        }?: run{
            // listenerの初期化に失敗しているのでエラー処理を行う
        }
    }
}
```

- 失敗はnullではなく例外で表現した方が良い場合もある

```kotlin
class MainActivity : AppCompatActivity() {
    // by lazyが初期化する型はnon-nullにする
    private val listener: IEventListener by lazy {
        // 初期化でエラーが発生したら例外を投げる
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            // listenerを使って何かする
            listener.doSomething()
        } catch (ex: InvalidParameterException) {
            // listenerの初期化に失敗しているのでエラー処理を行う
        }
    }
}
```

## lateinitやby lazyを指定した変数にはsmart-castが効かない
- 先のnullableの話と少し関連する
- `?`演算子によるnullチェックとscope関数を組み合わせた記述は強力
- だがjacocoによるC1カバレッジ測定を考慮に入れると面倒な場合が出てくる
- 素直にif文でチェックした方が良い場合もあるかも知れないが、by lazyやlateinitが付くとsmart-castが効かないケースがある

```kotlin
class MyClass(val x: Int){
    fun foo(){
        println(x)
    }
}

// by lazyでnullable型変数を初期化する
val myClass: MyClass? by lazy { MyClass(10) }
// lateinitでnullable型変数を初期化する
lateinit var myClass2: MyClass?
// by lazyもlateinitも付けない普通のパターン
val myClass3: MyClass? = MyClass(30)

fun failureSmartCast(){
    // if文でnullチェックしたくなった場合...
    if(myClass != null){
        // ↓の呼び出しは以下のエラーが発生する
        // Smart cast to 'TargetServices.MyClass' is impossible, because 'myClass' is a property that has open or custom getter
        myClass.foo()
    }

    if(myClass2 != null){
        // ↓のlateinit版も同様のエラーが発生する
        myClass2.foo()
    }
}

fun betterAccess(){
    // 通常はnullチェックをこう記述するので問題無いが...
    myClass?.foo()

    if(myClass3 != null){
        // by lazyもlateinitも付いてない方はちゃんとsmart-castが効く
        myClass3.foo()
    }
}
```

## モック化を考慮するとメンバ持ちobjectは作るべきではない

```kotlin
class TargetA : IListener{}
class TargetB : IListener{}
class TargetC : IListener{}

object MyObject{
    val targets: List<IListener> = listOf(
        TargetA(), TargetB(), TargetC()
    )
    fun onEvent(){
        targets.forEach { it.onEvent() }
    }
}
```

- ↑のような例だと`targets`が持つTargetA, TargetB, TargetCをmockk等でモック化しておきたい
- しかし、objectが持つメンバはunitTestでモック化を挟む隙も無く初期化されてしまう
- 初期化のタイミングをモック化の後に持ってくるためには、初期化タイミングを制御できなければならない
- 故に、objectにメンバは持たせるべきではなく、振る舞いのみを実装するべき
    - 実際に↑の例はobjectではなくclassにすることで対応した

## nullチェックのif-elseはscope関数で書くべきではない
```kotlin
fun foo(x: Int?){
    x?.also {
        // nullでない時にやる処理
        println(x)
    }?: run{
        // nullの時にやる処理
        println("null")
    }
}
```
- `?`演算子とscope関数を組み合わせるとnullチェックのif-elseは↑のように記述できる
    - ちなみにalsoの部分はletではダメ(letは最後の評価式を戻り値としてしまうため)
- kotlinらしく見えるが、これもjacocoでC1カバレッジ測定する際に困るポイントとなる
- `x`自体がnullのテストは簡単に記述できるのだが、alsoの戻り値がnoon-nullのテストが難しい
    - ↑のkotlin実装は↓のようなjavaコードになる
    - 一度nullチェックしたxに対して、もう一度nullチェックする分岐が生成されている

```Java
public final void foo(@Nullable Integer x) {
    boolean var3;
    boolean var4;
    boolean var6;
    boolean var8;
    if (x != null) {
        var3 = false;
        var4 = false;
        int it = ((Number)x).intValue();
        var6 = false;
        int var7 = x;
        var8 = false;
        System.out.println(var7);
        if (x != null) {
            // このパスを通すのが難しい
            return;
        }
    }

    var3 = false;
    var4 = false;
    TargetServices $this$run = (TargetServices)this;
    var6 = false;
    String var10 = "null";
    var8 = false;
    System.out.println(var10);
    Unit var10000 = Unit.INSTANCE;
}
```
