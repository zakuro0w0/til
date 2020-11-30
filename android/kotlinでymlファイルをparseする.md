# kotlinでymlファイルをparseする

## やりたいこと
- kotlinコードでyml文字列とymlオブジェクトの相互変換をしたい

## 参考にしたサイト
- [GitHub.com | charleskorn/kaml](https://github.com/charleskorn/kaml)
  - kotlinx.serializationにymlのparse機能を追加するplugin
  - kotlinx.serializationと組み合わせて使う必要がありそう
- [GitHub.com | kotlinx/serialization](https://github.com/Kotlin/kotlinx.serialization)
  - `@Serializable` annotationのために必要となるplugin
  - リフレクションを使ってないから処理が速いらしい
  - setupの手順を真似したものの手こずった
    - `org.jetbrains.kotlin.multiplatform`は要らない気がする
    - @Serializableするだけなら{module}/build.gradleに必要なのは`kotlinx-serialization-json`じゃなくて`kotlinx-serialization-core`と思われる
- [kotlinlang | Example: JSON serialization](https://kotlinlang.org/docs/reference/serialization.html#example-json-serialization)
- kotlin 1.4.0以前だと`kotlinx-sreialization-runtime`をimplementationするやり方だったらしい
  - [Kotlin Serialization事始め](https://qiita.com/toranoko0518/items/b4f0519c1db315f31c6b)
  - [Kotlin serializationの使い方を詳しく調べてみた](https://qiita.com/tarumzu/items/a2bb7fa0f597ff674314)

## 環境
- AndroidStudio: 3.6.3
- Target API Lv: 28(Android9.0 Pie)

## 必要なコード
### {project}/build.gradle

```groovy
// Top-level build file where you can add configuration options common to all sub-projects/modules.

buildscript {
    // ★1.4.10に書き換える
    ext.kotlin_version = '1.4.10'
    repositories {
        google()
        jcenter()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:3.6.3'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"

        // NOTE: Do not place your application dependencies here; they belong
        // in the individual module build.gradle files
    }
}

plugins {
    // ↓ GitHub.comのkotlinx.serializationでは必要っぽく書いてあったが、無くても動いた
    //id 'org.jetbrains.kotlin.multiplatform' version '1.4.10'

    // ★追加する
    id 'org.jetbrains.kotlin.plugin.serialization' version '1.4.10'
}

allprojects {
    repositories {
        google()
        jcenter()
    }
}

task clean(type: Delete) {
    delete rootProject.buildDir
}
```

### {module}/build.gradle

```groovy
apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply plugin: 'kotlin-android-extensions'

// ★追加する
apply plugin: 'kotlinx-serialization'

android {
    compileSdkVersion 29
    buildToolsVersion "29.0.2"

    defaultConfig {
        applicationId "com.example.ymlconvert"
        minSdkVersion 28
        targetSdkVersion 29
        versionCode 1
        versionName "1.0"

        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }

    // ★追加する
    // 起動時のBootstrapMethodError回避のため
    compileOptions {
        targetCompatibility = "8"
        sourceCompatibility = "8"
    }

}

dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
    implementation 'androidx.appcompat:appcompat:1.2.0'
    implementation 'androidx.core:core-ktx:1.3.1'
    implementation 'androidx.constraintlayout:constraintlayout:2.0.1'
    testImplementation 'junit:junit:4.12'
    androidTestImplementation 'androidx.test.ext:junit:1.1.2'
    androidTestImplementation 'androidx.test.espresso:espresso-core:3.3.0'

    // ★追加する
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-core:1.0.1")
    implementation("com.charleskorn.kaml:kaml:0.26.0")
}
```

### gradle-wrapper.properties
```
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-5.6.4-all.zip
```

### MainActivity.kt

```kotlin
package com.example.ymlconvert

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

// importは必須
import com.charleskorn.kaml.Yaml
import kotlinx.serialization.*

// @Serializableのannotationのためにkotlinx.serializationが必要
// kaml自体はkotlinx.serialization本体の機能を提供しない
@Serializable
data class Team(
    val leader: String,
    val members: List<String>
)

fun foo() {
    val input = """
        leader: Amy
        members:
          - Bob
          - Cindy
          - Dan
    """.trimIndent()
    // ここで@Serializableを付与したクラスのserializer()を呼び出している
    val result = Yaml.default.decodeFromString(Team.serializer(), input)
    println(result)
}


class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        foo()
    }
}
```