# robolectric + jacocoでカバレッジ測定

## やりたいこと
- AndroidTestとJUnitTestの両方をCIコンテナで実行し、カバレッジレポートを生成したい
- AndroidStudioのプロジェクトがマルチモジュールの場合、各モジュールのカバレッジレポートを1つにまとめたい

## 今回使うもの
- [jacoco](https://docs.gradle.org/current/userguide/jacoco_plugin.html)
    - カバレッジを測定し、レポートを出力するために必要
- [robolectric](http://robolectric.org/getting-started/)
    - AndroidTestをJUnitTestとして記述し、Androidデバイス無しでのテスト実行を可能にする
    - CIコンテナでのデバイスレステスト実行に必要
    - [robolectric 4.3.1](https://github.com/robolectric/robolectric/releases/tag/robolectric-4.3.1)の時点でAndroid API 29(Q)まで対応している

## 参考にしたWebサイト
- [Gradle6系 + Jacoco + マルチモジュール + フルKotlin + Android + Robolectric環境でユニットテストのカバレッジを出す](https://qiita.com/ryo_mm2d/items/e431326f701e74ec49fa#%E3%83%9E%E3%83%AB%E3%83%81%E3%83%A2%E3%82%B8%E3%83%A5%E3%83%BC%E3%83%AB)
- [Androidでコードカバレッジを計測する](https://developers.yenom.tech/entry/2018/04/15/152110)
- [マルチモジュールなAndroidプロジェクトでJaCoCoの設定を書く](https://subroh0508.net/articles/jacoco-scripts-in-anroid-muitl-module-project-by-kotlin-dsl)


## リポジトリ内で準備するファイル
### ディレクトリ構成
```
{repository}/
    ├── androidlib  // aarを作るmodule
    │   └── build.gradle
    ├── app         // apkを作るmodule
    │   └── build.gradle
    ├── build.gradle
    └── coverage.gradle
```

### {repository}/coverage.gradle
```groovy
apply plugin: "jacoco"

dependencies {
    testImplementation 'junit:junit:4.12'
    androidTestImplementation 'androidx.test.ext:junit:1.1.1'
    androidTestImplementation 'androidx.test.espresso:espresso-core:3.2.0'
    // robolectricで必要となる記述
    testImplementation 'androidx.test:core:1.2.0'
    testImplementation 'androidx.test:runner:1.2.0'
    testImplementation 'androidx.test:rules:1.2.0'
    testImplementation 'androidx.test.ext:junit:1.1.1'
    testImplementation 'androidx.test.ext:truth:1.2.0'
    testImplementation 'com.google.truth:truth:0.42'
    testImplementation 'org.robolectric:robolectric:4.3'
}

jacoco {
    toolVersion = "0.8.5"
}

android{
    testOptions {
        unitTests.all {
            jacoco {
                // robolectricで記述したテストのカバレッジ取得に必要
                includeNoLocationClasses = true
            }
        }
        unitTests{
            includeAndroidResources = true
            returnDefaultValues = true
        }
    }
    buildTypes{
        debug{
            testCoverageEnabled true
        }
    }
    sourceSets{
        test.java.srcDirs += 'src/test/java'
        androidTest.java.srcDirs += 'src/androidTest/java'
    }
}

// dependsOnでtestDebugUnitTestとの依存関係を作りたいが、上手く出来なかった
task jacocoMerge(
        type: JacocoMerge,
        group: "verification"
) {
    gradle.afterProject { project, _ ->
        if (project.rootProject != project && project.plugins.hasPlugin('jacoco')) {
            executionData "${project.buildDir}/jacoco/testDebugUnitTest.exec"
        }
    }
}

task jacocoMergedReport(
        type: JacocoReport,
        dependsOn: [tasks.jacocoMerge],
        group: "verification"
) {
    getExecutionData().from = jacocoMerge.destinationFile

    gradle.afterProject { project, _ ->
        if (project.rootProject != project && project.plugins.hasPlugin('jacoco')) {
            getSourceDirectories().from += "${project.projectDir}/src/main/java"
            getClassDirectories().from += project.fileTree(dir: "${project.buildDir}/tmp/kotlin-classes/debug")
        }
    }
    reports {
        xml.enabled = true
        html.enabled = true
    }
}
```

### {module}/build.gradle

```groovy
apply from: rootProject.file('coverage.gradle')
```

### テスト対象となるソースコード
```kotlin
package com.example.mylibrary

import android.os.Bundle
import com.google.android.material.snackbar.Snackbar
import androidx.appcompat.app.AppCompatActivity

import kotlinx.android.synthetic.main.activity_main.*

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        setSupportActionBar(toolbar)
    }
    /**
     * xとyを掛けた値を返す
     */
    fun multiple(x: Int, y:Int) = x * y
}

/**
 * x + yを返す
 */
fun add(x: Int, y: Int) = x + y
```

### UnitTest.kt
- androidTestではなく、JUnitTest側に全てのテストケースを実装する
- Activityなどandroid要素のテストはandroidxの機能を使って記述する

```kotlin
package com.example.mylibrary

import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ExampleUnitTest {
    @Test
    fun myAndroidtest(){
        assertEquals(2, 1+1)
        val scenario = ActivityScenario.launch(MainActivity::class.java)
        scenario.onActivity {
            val value = it.multiple(2, 30)
            assertEquals(50, it.multiple(5, 10))
        }
    }

    @Test
    fun myJUnitTest(){
        assertEquals(10, add(3, 7))
    }

}
```

## 使い方
- JUnitTestで定義したテストを実行して
```groovy
gradlew testDebugUnitTest
```

- 各モジュールのテスト結果を1つにまとめる
```groovy
gradlew jacocoMergedReport
```

- 今回試した時はapp配下のhtmlレポートにマージされていた
```
app/build/reports/jacoco/jacocoMergedReport/html/index.html
```
