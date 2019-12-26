# kotlin library on AndroidStudio
- kotlinコードを複数のmoduleで共有したい場合に使う
- Androidリソースやfragmentを共有したい場合はJavaライブラリではなくAndroidライブラリとして作る必要がある

## ライブラリの作成
- AndroidStudio >> プロジェクトエクスプローラ右クリック >> 新規 >> モジュール >> Javaライブラリ
- ライブラリ名(=パッケージ名)を入力 >> 完了
- 既定で作られるjavaファイルは削除
	- javaライブラリとして作った場合のdefaultで生成されるbuid.gradleを変更する必要あり
	- ['Unresolved reference' errors for android library module referenced in app module - Stack Overflow](https://stackoverflow.com/questions/49124353/unresolved-reference-errors-for-android-library-module-referenced-in-app-modul)

```
apply plugin: 'kotlin'

dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
}
```
- パッケージを右クリック >> 新規 >> kotlinファイル/クラス >> ファイル名入力 >> OK

## ライブラリのimport
- ライブラリを使用するモジュールのbuild.gradleを開く
- 以下のようにライブラリ名を指定する

```
dependencies{
	implementation project(':{libraryModuleName}')
}
```
- ライブラリで定義したクラスを使用するktファイルにて
```
import {packageName}.{className}
```