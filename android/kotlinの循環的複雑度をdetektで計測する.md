# kotlinの循環的複雑度をdetektで計測する

## やりたいこと
- kotlinの循環的複雑度を計測し、基準を満たしていないコードをCIで拒否したい

## 利用するもの
- [detekt](https://github.com/detekt/detekt)
- [detektリファレンス](https://detekt.github.io/detekt/index.html)

## 参考にした記事
- [Kotlinの静的解析ツール「detekt」のセットアップ&操作方法](https://qiita.com/uhooi/items/cd1250c6f6de7d4abfd6)
- [GitHub ActionsでAndroidアプリのCIを構築する方法](https://qiita.com/uhooi/items/70ffe67ba65d33189db2#detekt)
    > detekt を使って静的解析するジョブです。
    > Android Lintにはない観点で静的解析するため、両方とも使うのがオススメです。

## 前提となるディレクトリ構成
```
{repository}
    ├── app/
    ├── build.gradle
    ├── detekt.gradle
    ├── detekt.yml
    └── baseline.xml
```

### {repository}/build.gradle
```
plugins{
    id 'io.gitlab.arturbosch.detekt' version '1.9.1'
}
```

### {repository}/detekt.gradle
```groovy
apply plugin: 'io.gitlab.arturbosch.detekt'

detekt {
    failFast = true // fail build on any finding
    buildUponDefaultConfig = true // preconfigure defaults
    config = files("$rootDir/detekt.yml") // point to your custom config defining rules to run, overwriting default behavior
    baseline = file("$rootDir/baseline.xml") // a way of suppressing issues before introducing detekt

    reports {
        html.enabled = true // observe findings in your browser with structure and code snippets
        xml.enabled = true // checkstyle like format mainly for integrations like Jenkins
        txt.enabled = true // similar to the console output, contains issue signature to manually edit baseline files
    }
}
```

### {repository}/detekt.yml
- 書き方は[本家のdetekt.yml](https://github.com/detekt/detekt/blob/35e2b174e14c8995f1cb07351b1ea26df29065ed/config/detekt/detekt.yml)を参考に
- 検査項目は`active: true`となっているもの全て
- detekt.ymlで意図的に`active: false`としなければ検査される
- 検査項目毎に`weights`による重みづけが可能で、weightsの合計値が`maxIssues`を超えるとgradleタスクとして失敗する
    - CIパイプライン上でも恐らく失敗扱いになる
    - `maxIssues`のデフォルト値は0なので、1つでも違反が見つかれば失敗する最も厳しい設定になっている
- 関数の循環的複雑度の閾値はデフォルトで15だが、カスタムしたい場合はdetekt.ymlで明記する必要がある
    - 例えば↓の例では閾値を10にしている
- exclude設定もできそうなので、OSS等のソースコードは除外するべきだろう
- ルールの選定はかなり難しそうなので、とりあえずデフォルトで始めて随時調整するのが良いだろう

```yml
build:
 maxIssues: 3
 weights:
   MagicNumber: 0
   ComplexMethod: 3

console-reports:
  active: true
  exclude:
  #  - 'ProjectStatisticsReport'
  #  - 'ComplexityReport'
  #  - 'NotificationReport'
  #  - 'FindingsReport'
  #  - 'FileBasedFindingsReport'
  #  - 'BuildFailureReport'

processors:
  active: true
  exclude:
  # - 'FunctionCountProcessor'
  # - 'PropertyCountProcessor'
  # - 'ClassCountProcessor'
  # - 'PackageCountProcessor'
  # - 'KtFileCountProcessor'

complexity:
  active: true
 ComplexMethod:
   active: true
   threshold: 10
   ignoreSingleWhenExpression: false
   ignoreSimpleWhenEntries: false
   ignoreNestingFunctions: false
   nestingFunctions: [run, let, apply, with, also, use, forEach, isNotNull, ifNull]
```

### {repository}/baseline.xml
```xml
<SmellBaseline>
    <Blacklist>
    </Blacklist>
    <Whitelist>
    </Whitelist>
</SmellBaseline>
```

## detektによる静的解析の実行
```shell
gradlew detekt
```

## 実行時に閾値に引っかかった時の例
- 例えばMainActivity.ktに↓のような関数を定義してdetektを実行した場合...
```kotlin
fun foo(x: Int, y: Int, z: Int, w: Int){
    when(x){
        10-> println("a")
        11-> println("a")
        12-> println("a")
        13-> println("a")
        14-> println("a")
        15-> println("a")
        16-> println("a")
        17-> println("a")
        18-> println("a")
        19-> println("a")
        20-> println("a")
        21-> println("a")
        22-> println("a")
        23-> println("a")
        24-> println("a")
        25-> println("a")
    }
}
```

- ↓のようなコンソール出力が得られる
    - MagicNumberとComplexMethodの項目でNGになっていることが分かる
```
18:27:41: Executing task 'detekt'...

Executing tasks: [detekt] in project D:\programs\android\projects\detektTest\app


> Configure project :
Inferred project: detektTest, version: 0.1.0-dev.3.uncommitted+feature.a52280c

> Task :app:detekt FAILED
complexity - 20min debt
	ComplexMethod - 17/10 - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:15:5
style - 2h 40min debt
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:17:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:18:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:19:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:20:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:21:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:22:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:23:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:24:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:25:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:26:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:27:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:28:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:29:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:30:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:31:9
	MagicNumber - [foo] at D:\programs\android\projects\detektTest\app\src\main\java\com\example\detektTest\MainActivity.kt:32:9

Overall debt: 3h


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:detekt'.
> Build failed with 17 weighted issues (threshold defined was 0).
```