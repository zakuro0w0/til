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