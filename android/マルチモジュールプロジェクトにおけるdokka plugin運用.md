# マルチモジュールプロジェクトにおけるdokka plugin運用
## AndroidStudio + kdoc(dokka plugin)運用の注意
- 以下のようなモジュール構成の場合、`gradlew apkModule:dokka`によるkdoc生成は失敗する
	- これは、apkからjarライブラリを参照しているため(aarへの参照は無害)
	- Androidと関係の無い定義をjarで共有することは普通にあり得るので、かなり困る
```
projectRoot/
├── apkModule // jarとaarをimportする
├── aarModule
└── jarModule
```

## jarを参照するapkのdokkaタスクが失敗する原因の調査
- jarを生成するプロジェクトの作り方の問題か？ >> NO
- あるいはdokkaプラグインのconfigurationか？ >> YES
- [Kotlin + dokka でマルチモジュールのJavadocを生成 - mstのらぼ](http://mst335.hatenablog.com/entry/2019/09/27/173056)
	- マルチモジュール構成の場合に色々dokkaの設定を工夫する必要があった模様
	- ↑の記事ではdokka ver0.9.18を使用
	- 今はdokka ver0.10.0を使用中(includeNonPublicの設定が必要なため)
	- dokka ver0.10.0でgradleに記述する項目名が結構変わっている
	- ↑で公開されてるリポジトリをcloneしてそのままgradlew dokkaしたらちゃんと動くが、ver0.10.0に差し替えてみると動かない
- [Kdoc for Android libraries using Dokka - Jeroen Mols](https://jeroenmols.com/blog/2020/02/19/dokka-code-documentation/)
	- ↑の記事はdokka{ configuration{} }があるのでver0.10.0以上を使っていると思われる(記事の日付も2020.02.19とかなり新しい)
	- githubのコードを公開している訳ではないので、全体像がつかめない
	- [Bringing it all together](https://jeroenmols.com/blog/2020/02/19/dokka-code-documentation/#bringing-it-all-together)のgradleを真似してみたが、足りない記述がいくつかある模様

## マルチモジュールプロジェクトdokka問題の解決方法
- 各モジュールにdokka.gradleをapplyとかは要らない
- 全モジュールのkdocを一括で出力するための空モジュール(AndroidLibrary)が必要
	- このモジュールのbuild.gradleにdokka周りの設定とgradle scriptを仕込む
	- [Kdoc for Android libraries using Dokka - Jeroen Mols](https://jeroenmols.com/blog/2020/02/19/dokka-code-documentation/#bringing-it-all-together)
		- 基本的には↑の真似
		- import groovy.io.FileTypeが不足していた
		- getSourceRootsToDocumentAsStrings()でのディレクトリ探索は$rootDir配下全部を指定しておけばOK
			- 特に対象モジュールを個別に指定する必要は無し
		- getInternalPackages()
			- "internal"をパスに含むpackageは除外されてるっぽい
	- dokka.gradleファイルに保存しておき、documentation module/build.gradleからはdokka.gradleを外部ファイルとしてapplyするだけにしたかった
		- が、dokka.gradleに分離するとimportで参照できないとエラーになる
		- moduleのbuild.gradleに書かないといけないかも？

### 1. 新規 >> モジュール >> Androidライブラリ >> kdocモジュールを追加

### 2. kdoc/build.gradleに以下をコピペ
```gradle:kdoc/build.gradle
import org.jetbrains.dokka.gradle.GradleSourceRootImpl
import groovy.io.FileType
apply plugin: 'com.android.library'
apply plugin: 'org.jetbrains.dokka'

android {
    compileSdkVersion 29
    defaultConfig {
        minSdkVersion 28
        targetSdkVersion 29
    }
}

/**
 * Androidのマルチモジュールプロジェクトにおいて、kdocドキュメントを出力するための設定.
 *
 * 通常はdokkaプラグインを各モジュールに適用し、`gradlew dokka`コマンドでkdocドキュメントを出力可能だが、
 * モジュールがプロジェクト配下に複数あり、apkを作るモジュールからjarを作るモジュールへの参照があると
 * apkに対する`gradlew dokka`コマンドが失敗することが分かっている.
 *
 * これを回避するため、kdoc出力専用でソースコードを持たないモジュールをAndroidライブラリとして作り、
 * このbuild.gradleにて他のモジュールのソースコードを探索、kdocとして出力する方法を採用した.
 * このkdoc出力用モジュールを定義した後、ターミナルにて`gradlew dokka`コマンドを実行することで
 * kdoc出力用モジュール/build/kdoc/配下にプロジェクト内の全モジュールのkdocドキュメントが出力される.
 *
 * dokkaのversionは2020.03.03現在最新の0.10.1を想定している.
 * 0.9.18以前と0.10.0以降ではdokka設定の書式がかなり変わっているため注意.
 * ```:project/build.gradle
 * buildscript{
 *      ext.dokka_version = '0.10.1'
 *      dependencies{
 *          classpath "org.jetbrains.dokka:dokka-gradle-plugin:${dokka_version}"
 *      }
 * }
 * ```
 *
 * 参考URL: https://jeroenmols.com/blog/2020/02/19/dokka-code-documentation/#bringing-it-all-together
 */

dokka {
    outputFormat = 'html' // use 'javadoc' to get standard java docs
    outputDirectory = "$buildDir/kdoc"

    configuration {
        includeNonPublic = true
        skipEmptyPackages = true
        skipDeprecated = true
        reportUndocumented = true
        jdkVersion = 8

        sourceRoots = getSourceRootsToDocument()
        for (String p in getInternalPackages()) {
            perPackageOption {
                prefix = p
                suppress = true
            }
        }
    }
}

private List<String> getInternalPackages() {
    def sourceRoots = getSourceRootsToDocumentAsStrings()
    def internalPackages = new ArrayList<String>()

    for (String root in sourceRoots) {
        def subPackages = getAllSubDirectories(new File(root))
                .findAll { it.path.contains("internal") }
                .collect { it.path.split("src/main/java/")[1].replaceAll("/", ".") }
        internalPackages.addAll(subPackages)
    }
    return internalPackages
}

private List<File> getAllSubDirectories(File directory) {
    def list = new ArrayList<String>()
    directory.eachFileRecurse (FileType.DIRECTORIES) { file ->
        list << file
    }
    return list
}

// Converts the source path Strings into SourceRoot
private List<GradleSourceRootImpl> getSourceRootsToDocument() {
    return getSourceRootsToDocumentAsStrings().collect {
        def impl = new GradleSourceRootImpl()
        impl.path = it
        impl
    }
}

private List<String> getSourceRootsToDocumentAsStrings() {
    def sources = new ArrayList<>()
    sources += getSourceDirs("$rootDir")
    // add other locations of sources here
    sources
}

private List<String> getSourceDirs(String directoryPath) {
    file(directoryPath).listFiles()
            .findAll { it.isDirectory() && it.name != "build" } // Non build subfolders
            .collect { "${it.path}/src/main/java" } // path of main sources
            .findAll { new File(it).exists() } // only include if path exists
}
```

### 3. terminalで`gradlew dokka`

### 4. projectRoot/kdoc/build/kdoc/配下にドキュメントが出力される
