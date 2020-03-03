# ktlint
- [[Android] ktlint の導入と感想 - Qiita](https://qiita.com/hkusu/items/f1c55a0e0d03543b24d5)
> `gradlew ktlintFormat` でコード修正までやってくれる

- ktlintを生で使うにはgradleタスクを自分で定義したりと面倒
	- [Danger + ktlintでPull RequestのKotlinコードスタイルを自動チェックさせる (Travis CI編) - Qiita](https://qiita.com/kafumi/items/1a9f59d6f845808604df)
	- ここで紹介されているktlint-gradleプラグインを使うことにしてみる

#### gradle設定
- project/build.gradle
```:project/build.gradle
buildscript {
	// ktlintをgradleプラグインでwrapしたやつのバージョン
	ext.ktlint_gradle_version = '9.2.1'
	// ktlint本体のバージョン
	ext.ktlint_version = '0.36.0'
	
	repositories {
		maven { url "https://plugins.gradle.org/m2/" }
	}
	
	dependencies {
		classpath "org.jlleitschuh.gradle:ktlint-gradle:${ktlint_gradle_version}"
	}
}
```

- [GitHub - JLLeitschuh/ktlint-gradle: A ktlint gradle plugin](https://github.com/JLLeitschuh/ktlint-gradle#configuration)
	- Groovyのconfigurationを真似すればよい
	- sampleは↓にもある
	- [ktlint-gradle/build.gradle at master · JLLeitschuh/ktlint-gradle · GitHub](https://github.com/JLLeitschuh/ktlint-gradle/blob/master/samples/kotlin-gradle/build.gradle)
- ktlint内の設定項目の説明は？	
	- [ktlint-gradle/KtlintExtension.kt at master · JLLeitschuh/ktlint-gradle · GitHub](https://github.com/JLLeitschuh/ktlint-gradle/blob/master/plugin/src/main/kotlin/org/jlleitschuh/gradle/ktlint/KtlintExtension.kt)
		- ktlintExtension.kt定義のプロパティが設定可能らしい
- project/ktlint.gradle
```:project/ktlint.gradle
apply plugin: "org.jlleitschuh.gradle.ktlint"

ktlint {
	// ktlint本体のバージョン(プラグインktlint-gradleとは違うので注意)
	version = "${ktlint_version}"
    debug = true
    verbose = true
	// Android Kotlin Style Guide に準拠したスタイルチェックを行うか否か
    android = true
	// terminalに出力する実行結果における違反ルール名に色を付けるか否か
	coloredOutput = true
	// 違反したルール名に付ける色
    outputColorName = "RED"
    reporters{
		// レポートをxml形式で出力させる
        reporter "checkstyle"
		// レポートをtxt形式で出力させる
        reporter "plain"
        customReporters {
			// レポートをhtml形式で出力させる
            "html" {
                fileExtension = "html"
                dependency = "me.cassiano:ktlint-html-reporter:0.2.3"
            }
        }
    }
	// 指摘が出た際のgradleビルド失敗を無視するか否か
	// trueにしておくと指摘のレポートを出力しつつ、ビルドはsuccessに出来る
    ignoreFailures = true
}
```

- module/build.gradle
```:module/build.gradle
apply from: rootProject.file('ktlint.gradle')
```

#### 使い方

- ルールに反する箇所を指摘するレポートを出力する(コードは書き換えない)
	- レポートは`{project}/{module}/build/reports/ktlint/***.html`に出力される
```
gradlew ktlintCheck
```

- ルールに従い強制的にコードを書き換える
	- Android developerとjetbrains kotlin公式のスタイルガイドに準拠したルールらしい
		- [Kotlin スタイルガイド  \|  Android デベロッパー  |  Android Developers](https://developer.android.com/kotlin/style-guide)
		- [Coding Conventions - Kotlin Programming Language](https://kotlinlang.org/docs/reference/coding-conventions.html)
```
gradlew ktlintFormat
```

#### ルールのカスタム方法
- [ktlint::EditorConfig](https://github.com/pinterest/ktlint#editorconfig)
	- [EditorConfig](https://editorconfig.org/#example-file)ファイルの記述で色々カスタムできる
	- [[Android] ktlint の導入と感想 - Qiita](https://qiita.com/hkusu/items/f1c55a0e0d03543b24d5#lint-の実行)
		- ↑の人はmax_line_length=128で1行あたりの最大文字数をカスタムしている
		- ルール名は[ruleset/standard/*.kt](https://github.com/pinterest/ktlint/blob/master/ktlint-ruleset-standard/src/main/kotlin/com/pinterest/ktlint/ruleset/standard/NoWildcardImportsRule.kt)を参照
			- ソースコード内のRule()に与える文字列がルール名

```:.editorconfig
# Unix-style newlines with a newline ending every file
[*]
end_of_line = lf
insert_final_newline = true

[*.{kt,kts}]
max_line_length = 128

# カンマ区切りで無効にしたいルールを並べる
#disabled_rules = no-wildcard-imports
```