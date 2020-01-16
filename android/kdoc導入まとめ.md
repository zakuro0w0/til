# kdocドキュメント自動生成
- dokka + kdoc-generatorによるkotlin document環境の導入まとめ
- dokka : ソースコード内のkdoc書式に従ったコメントからドキュメントを作成する
- kdoc-generator : 関数の手前で`/**`と入力 >> Enterでkdoc書式のtemplateを自動生成する

---
## ディレクトリ構成

```
project/
├── build.gradle
└── module
    ├── build.gralde
    └── src
        └── main.kt
```

---
## kdoc-generator導入手順
1. AndroidStudio起動
2. メニュー >> ファイル >> 設定 >> プラグイン
3. マーケットプレースで"kdoc-generator"を検索
4. Installボタン押下

---
## dokka導入手順
1. プロジェクト直下のbuild.gradle変更

```:project/build.gradle
buildscript{
	...
	ext.dokka_version = '0.10.0'
}

dependencies{
	classpath "org.jetbrains.dokka:dokka-gradle-plugin:${dokka_version}"
}
```

2. dokka設定をプロジェクト配下のモジュール間で共有するためのdokka.gradleを作成

```:project/dokka.gradle
apply plugin: 'org.jetbrains.dokka'
dokka {
    outputFormat = 'gfm'
    outputDirectory = "$buildDir/kdoc"
    configuration {
        includeNonPublic = true
    }
}
```

3. モジュール直下のbuild.gralde変更

```:module/build.gradle
apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'
apply plugin: 'kotlin-android-extensions'

android {
    compileSdkVersion 29
    buildToolsVersion "29.0.2"
    defaultConfig {...}
    buildTypes {
        release {...}
    }
    packagingOptions {...}
}

dependencies {...}

apply from: rootProject.file('dokka.gradle')
```

3. Gradleファイルとプロジェクトを同期

---
### 使い方
1. kdocコメントを書く
	- 実装した関数の上で`/**`と入力してからEnter
	- kdoc-generatorの機能により、関数のプロトタイプに応じたkdoc templateが自動生成される
	- 後は各引数や戻り値の説明を記入する
		- [KDoc 書き方メモ(Kotlin のドキュメンテーションコメント) - Qiita](https://qiita.com/opengl-8080/items/fe43adef48e6162e6166#基本文法)
	- 2020.01時点のdokka ver0.10.0ではkdocコメント内の改行が生成されるドキュメントに反映されない
		- `<br>`, `<pre>`タグ、LF(\n)は効果無し
		- markdown書式の半角スペース2個、空行を挟んでも効果無し
		- `##`による見出しを行頭に付ければ改行できるが、面倒すぎるので無し

```kotlin:main.kt
/**
 * [x] と [y] の合計値を返す
 *
 * @param x
 * @param y
 * @return [x]と[y]の合計値
 */
fun sum(x: Int, y:Int): Int{
	return x + y
}
```

2. ドキュメントを出力する
	- AndroidStudioでターミナルを開き、以下のコマンドを実行
	- dokkaはAndroidDeveloperへのリンクを自動挿入するため、プロキシを突破できる状態か、プロキシの無いネットワーク環境で実行する必要があるため注意

```
gradlew dokka
```
