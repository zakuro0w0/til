# デバイス電源ON時にsharedPreferenceを初期化する

## やりたいこと
- タイトルのまま
- androidデバイスの電源がONになった時、ActivityがsharedPreferenceに保存している設定値を初期化したい
- Activityが起動していなくても設定値が初期化されるようにしたい

## SharedPreferenceの読み書きが出来るようにする

### SharedPreference概要
- apkが終了しても、デバイスの電源がOFFになっても永続する設定値保存の仕組み
- `/data/data/{packageName}/shared-pref/***.xml`として保存される
- いくつか用意された方法で`SharedPreference`インスタンスを取り出す
    - 書き込む時は`edit{}`ブロック内で`putInt(key, value)`等を呼び出した後、最後に`commit()` or `apply()`で反映させる
    - 読み込む時は`getInt(key, defaultValue)`等を使う

### SharedPreferenceの作法
- preferenceにファイル名指定ではアクセスしたくない(名前を間違えるリスクを取りたくない)
    - 名前指定無しでのアクセスには`getDefaultSharedPreferences()`が必要
    - だが、これを提供する`PreferenceManager`は@Deprecatedになっている
    - [PreferenceManagerが@Deprecatedで困った話 - Qiita](https://qiita.com/kph7mgb/items/bdaab20ca708df571b46)
- なので、`preference-ktx`を使おう
    - [Preference  \|  Android デベロッパー  |  Android Developers](https://developer.android.com/jetpack/androidx/releases/preference?hl=ja)
        - 2020.04.15時点の最新は1.1.1
        - package名も`androidx.preference:preference`ではなく`androidx.preference:preference-ktx`になっている
- `SharedPreference::putInt()`のような型名付き関数を`put()`にまとめる例は以下が参考になった
    - [ぼくの考えた最強のSharedPreferences](https://qiita.com/susu_susu__/items/76a59e0cf6c93db74bd7)

### {module}/build.gradle
```groovy:build.gradle
dependencies {
    implementation 'androidx.preference:preference-ktx:1.1.1'
}
```

### MainActivity.kt
```kotlin
//import android.preference.PreferenceManager // @Deprecated
import androidx.preference.PreferenceManager

fun foo(context: Context){
    // Activityが見えない場所からのアクセスにはContextが必須
    // PreferenceManager経由ならファイル名指定は不要
    PreferenceManager.getDefaultSharedPreferences(context).edit{
        putInt("foo", 100)
        commit()
    }
}

class MainActivity : AppCompatActivity() {
    fun bar(){
        // Activity配下ならファイル名指定無しでアクセスできる
        // が、Activity::getPreferences()でアクセスするxmlはこの場合MainActivity.xmlであり、
        // PreferenceManager経由でアクセスできるxmlとは別物なので注意
        this.getPreferences(Context.MODE_PRIVATE).edit{
            putInt("bar", 200)
            commit()
        }
    }
    
    fun hoge(){
        // foo()と同じファイルに書き込むにはPreferenceManagerを経由するか、
        // Context::getSharedPreferences()にパッケージ名を指定するか
        this.androidContext.getSharedPreferences(this.packageName, Context.MODE_PRIVATE).edit{
            putInt("hoge", 300)
            commit()
        }
    }
}
```


## 電源ONのタイミングを検出し、実行したい処理を呼び出せるようにする

### AndroidManifest.xml
- [BOOT_COMPLETED](https://developer.android.com/reference/android/content/Intent#ACTION_BOOT_COMPLETED)のIntentを受信するBroadcastReceiverを登録しておく必要がある
- `RECEIVE_BOOT_COMPLETED`のpermissionもセットで必要
- AndroidManifest.xmlにReceiverを定義しておくことで、Activityが起動してない時でも動くように出来る

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest ...>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <application ...>
        <receiver android:name=".BootCompletedReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

### BroadcastReceiverの実装
```kotlin
import androidx.preference.PreferenceManager

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        // ここに実行したい処理を実装する
        PreferenceManager.getDefaultSharedPreferences(context).edit{
            clear()
            commit()
        }
    }
}
```