# jacocoでカバレッジ測定

## project/build.gradle
- 特に変更は不要

## module/build.gradle

```gradle:module/build.gradle
apply from: rootProject.file('jacoco.gradle')
```

## apkモジュール用jacoco.gradle
- android.applicationVariantsはapkモジュール用
	- [LibraryExtension - Android Plugin 3.3.0 DSL Reference](http://google.github.io/android-gradle-dsl/3.3/com.android.build.gradle.LibraryExtension.html#com.android.build.gradle.LibraryExtension:jacoco)
		- libraryVariantsもある, jarやaarのモジュールはこちらだろう
- マルチモジュールプロジェクトの場合は全てのモジュールのカバレッジ測定結果をマージし、プロジェクト全体としての結果も出す必要があり、jacoco.gradleはまた違ったものが必要になるだろう

```gradle:jacoco.gradle
/*
# 参考URL
https://qiita.com/keidroid/items/adc4f065b84d8a2cd17a#androidtestとunittestをマージしkotlin対応するjacoco設定
*/

apply plugin: 'jacoco'

android{
    buildTypes{
        debug{
            testCoverageEnabled true
        }
    }
}

jacoco {
    toolVersion = "0.8.5" //ツールバージョンを指定可能。省略可。
}

// # 今のところこの設定は上手く動かず、Windowsの環境変数追加で対応している状況、gradleファイルでencodeを設定したい
// https://teratail.com/questions/207665#reply-306959
// コンパイル時に使用する文字コードをUTF-8で固定する
tasks.withType(AbstractCompile).each { it.options.encoding = 'UTF-8' }
tasks.withType(Test) {
    systemProperty "file.encoding", "UTF-8"
}

android.applicationVariants.all { variant ->
    def variantName = variant.name.capitalize() //ex. ProdDebug
    def realVariantName = variant.name //ex. prodDebug

    if (variant.buildType.name != "debug") {
        return
    }

    task("jacoco${variantName}TestReport", type: JacocoReport) {
        //AndroidTest後にUnitTestの内容をマージします。
        dependsOn "create${variantName}CoverageReport"
        dependsOn "test${variantName}UnitTest"

        group = "testing"
        description = "Generate Jacoco coverage reports for ${realVariantName}"

        reports {
            xml.enabled = false
            html.enabled = true
        }

        //無視するファイル(excludes)の設定を行います
        def fileFilter = ['**/R.class',
                          '**/R$*.class',
                          '**/BuildConfig.*',
                          '**/Manifest*.*',
                          'android/**/*.*',
                          'androidx/**/*.*',
                          '**/Lambda$*.class',
                          '**/Lambda.class',
                          '**/*Lambda.class',
                          '**/*Lambda*.class',
                          '**/*Lambda*.*',
                          '**/*Builder.*'
        ]
        def javaDebugTree = fileTree(dir: "${buildDir}/intermediates/javac/${realVariantName}/compile${variantName}JavaWithJavac/classes", excludes: fileFilter)
        def kotlinDebugTree = fileTree(dir: "${buildDir}/tmp/kotlin-classes/${realVariantName}", excludes: fileFilter)

        def mainSrc = "${project.projectDir}/src/main/java"

        getSourceDirectories().setFrom(files([mainSrc]))
        //Java, Kotlin混在ファイル対応
        getClassDirectories().setFrom(files([javaDebugTree, kotlinDebugTree]))
        getExecutionData().setFrom(fileTree(dir: project.projectDir, includes: [
                '**/*.exec',    //JUnit Test Result
                '**/*.ec'])     //Espresso Test Result
        )
    }
}
```

## Windowsのユーザ環境変数
- jacocoのレポートhtmlのSJIS文字化けを回避するために必要
	- 本来はgradleファイルの中でencode設定を効かせるべきだがまだ手段が見つかっていない
- key: JAVA_TOOL_OPTIONS
- value: -Dfile.encoding=UTF8

## カバレッジ測定の実行
- jacoco.gradleをapplyしたモジュールのAndroidTestとUnitTestを実行し、結果をマージしてレポート出力する
- AndroidTestを実行する都合上、AndroidStudioから接続可能なdevice(実機かemulator)が必要
- カバレッジ測定の前にprojectをビルドし、emulatorを起動しておく必要がある

```
gradlew jacocoDebugTestReport
```

## カバレッジレポートの確認
- `{module}/build/reports/jacoco/jacocoDebugTestReport/html/index.html`に出力される