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
	ext.dokka_version = '0.9.17'
}

dependencies{
	...
	classpath "org.jetbrains.dokka:dokka-android-gradle-plugin:$dokka_version"
}
```

2. モジュール直下のbuild.gralde変更

```:module/build.gradle
apply plugin: 'org.jetbrains.dokka-android'

dokka {
	// html以外にjavadoc, markdown, gfm(github fravored markdown)も選べる
    outputFormat = 'html'
	// ドキュメントの出力先指定
    outputDirectory = "$buildDir/kdoc"
}
```

3. Gradleファイルとプロジェクトを同期

---
### 使い方
1. kdocコメントを書く
	- 実装した関数の上で`/**`と入力してからEnter
	- kdoc-generatorの機能により、関数のプロトタイプに応じたkdoc templateが自動生成される
	- 後は各引数や戻り値の説明を記入する
		- [KDoc 書き方メモ(Kotlin のドキュメンテーションコメント) - Qiita](https://qiita.com/opengl-8080/items/fe43adef48e6162e6166#基本文法)

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

```
gradlew dokka
```

