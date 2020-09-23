# androidのキーイベントメモ

## 検証したいこと
- webAPIをキーイベントに変換してapkに通知したい
- apkのプロセスに対して、apkの外からキーイベントを通知する最適な方法はどれか？

## キーイベント送信方法の候補
- dispatchKeyEvent(): Activity自身に送信させる必要がある
- instrumentation: UIテスト用の機能なので製品コードに載せるべきか？
- injectKeyEvent: reflectionで無理やりprivate関数を呼ぶ必要があるらしい
- inputコマンド: root権限が必要らしい
- intent broadcast: 普通に可能だが、キーイベントではなくなる
- webAPI: apkが直接受け取る

## dispatchKeyEvent()

### apkプロセス内で呼び出す場合
- buttonがクリックされたら`B`キーのイベントを発行する
- キーイベントをdispatchKeyEvent()で拾い、`B`キーだったらTextViewに1文字追加する
- Activityの中からキーイベントを発行するのは問題無くできる
- 参考にしたwebサイト
  - [キーイベントを発行する](https://seesaawiki.jp/w/moonlight_aska/d/%A5%AD%A1%BC%A5%A4%A5%D9%A5%F3%A5%C8%A4%F2%C8%AF%B9%D4%A4%B9%A4%EB)
  - [[Android] ConstraintLayout による制約を設定するには](https://akira-watson.com/android/constraintlayout.html)


```kotlin
import android.os.Bundle
import android.view.KeyEvent
import androidx.appcompat.app.AppCompatActivity
import kotlinx.android.synthetic.main.activity_main.*

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        button.setOnClickListener{
            dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_B))
        }
    }
    override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
        when(event?.keyCode){
            KeyEvent.KEYCODE_B -> textView.append("b")
        }
        return super.dispatchKeyEvent(event)
    }
}
```

### Activity外から(例えばServiceから)呼び出す場合
- [stackoverflow: How use dispatchKeyEvent() in Service?](https://stackoverflow.com/questions/23185320/how-use-dispatchkeyevent-in-service)
  - 自分と全く同じ疑問が投稿されていた
  - `dispatchKeyEvent()`はActivityやViewクラスの定義であり、overrideする必要があるため、Serviceの中からは呼び出せない

> How i can use above line code in Service
> You can't.

>I think dispatchKeyEvent method exist in Activity class and not Exist in Service class.
> Correct. Services do not have a UI and therefore do not have key events to be dispatched.

## instrumentation
- [Testing and Instrumentation](https://sites.google.com/site/androidtestclub/translation/testing-and-instrumentation)
  - いつ頃の記事なのかは分からず、今も同じ仕様なのかは分からない
  - が、instrumentationを使う時はtest.apkとapp.apkが同じプロセス上で動くように見える
  - test.apkを使わずにapp.apkからinstrumentationの機能を使えるなら良いかも知れないが、やはりテストフレームワークの機能を製品コードのために使うのは気持ちが悪い

### app.apkからinstrumentation使ってみる
- [Androidのテストでクリップボードから貼り付ける](https://gist.github.com/esmasui/f00e255e60a69e20a1c0)
- [テストでCtrlキーとの組み合わせたキーをSendKeysする方法](https://groups.google.com/g/android-group-japan/c/2IJpWkjnCw8?pli=1)


#### app/build.gradle
- 後から考えるとテストバイナリでないapp.apkにimplementationでtest系packageを依存させるのはかなり違和感、普通はやらないのでは？
```groovy
dependencies {
    // for instrumentation key sending
    implementation 'androidx.test:runner:1.1.0'
    implementation 'androidx.test:rules:1.1.0'
    implementation 'org.hamcrest:hamcrest-library:1.3'
    implementation 'androidx.test.espresso:espresso-core:3.1.0'
    implementation 'androidx.test.uiautomator:uiautomator:2.2.0'
}
```

#### MainActivity.kt
```kotlin
package com.example.ktorsample

import android.os.Bundle
import android.view.KeyEvent
import androidx.appcompat.app.AppCompatActivity
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.android.synthetic.main.activity_main.*

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        button.setOnClickListener{
            foo()
        }
    }

    fun foo(){
        InstrumentationRegistry.getInstrumentation().let{
            it.sendKeySync(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_B))
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
        when(event?.keyCode){
            KeyEvent.KEYCODE_B -> textView.append("b")
        }
        return super.dispatchKeyEvent(event)
    }
}
```

- emulatorへのinstall時にエラーが出た
  - [How to fix ("cmd package install-create -r -t  -S 1699739' returns error 'Unknown failure: cmd: Can't find service: package") error when i launch the emulator.](https://stackoverflow.com/questions/57256664/how-to-fix-cmd-package-install-create-r-t-s-1699739-returns-error-unknown)
  - 調べるとemulatorの設定をAVDマネージャから変更しろ、とのこと
    - quick bootじゃなくてcold bootにするといいよ、らしい
    - 確かにこの対応でちゃんと起動するようになった
- app.apkを起動し、send keyボタンを押下すると例外でアプリが落ちた
```
E/AndroidRuntime: FATAL EXCEPTION: main
    Process: com.example.ktorsample, PID: 6337
    java.lang.IllegalStateException: No instrumentation registered! Must run under a registering instrumentation.
        at androidx.test.platform.app.InstrumentationRegistry.getInstrumentation(InstrumentationRegistry.java:45)
        at com.example.ktorsample.MainActivity.foo(MainActivity.kt:24)
        at com.example.ktorsample.MainActivity$onCreate$1.onClick(MainActivity.kt:19)
        at android.view.View.performClick(View.java:6597)
        at android.view.View.performClickInternal(View.java:6574)
        at android.view.View.access$3100(View.java:778)
        at android.view.View$PerformClick.run(View.java:25885)
        at android.os.Handler.handleCallback(Handler.java:873)
        at android.os.Handler.dispatchMessage(Handler.java:99)
        at android.os.Looper.loop(Looper.java:193)
        at android.app.ActivityThread.main(ActivityThread.java:6669)
        at java.lang.reflect.Method.invoke(Native Method)
        at com.android.internal.os.RuntimeInit$MethodAndArgsCaller.run(RuntimeInit.java:493)
        at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:858)
```

#### 実行時の例外について
- [AndroidでContextが必要な機能のテストコードを簡単に書こうとしてとても時間がかかった話](https://qiita.com/hotdrop_77/items/adf0d706c0fbc4c0a5c9)
- [Robolectric (v4.3)の導入で迷える子羊を俺が救う[ Android / testing ]](https://qiita.com/nanoyatsu/items/cc2af0d792fad74afe2d)
- [Build local unit tests (No instrumentation registered! Must run under a registering instrumentation) [duplicate]](https://stackoverflow.com/questions/54222533/build-local-unit-tests-no-instrumentation-registered-must-run-under-a-register/54648161)
- [AndroidX : No instrumentation registered! Must run under a registering instrumentation](https://stackoverflow.com/questions/53595837/androidx-no-instrumentation-registered-must-run-under-a-registering-instrumen)
- 当たり前かも知れないが、↑はどちらもテストバイナリの実装で困っており、製品バイナリであるapp.apkでinstrumentationを使おうとしている訳ではない

## intentをbroadcast
- [他のMedaipPlayerを止める](https://asari-mtr.hatenadiary.org/entry/20120115/1326607083)
- [intent/EXTRA_KEY_EVENT](https://developer.android.com/reference/android/content/Intent?hl=ja#EXTRA_KEY_EVENT)
- [How Media API works in Android](https://qiita.com/KeithYokoma/items/ed873676ecb28196781f)

### どういうintentでやり取りするか
- webAPIのkey毎にintent.actionを用意する方法もある
- が、受け取りたいintent.actionの数だけapp.apkはintent-filterをmanifest.xmlに定義する必要がある
  - あまり沢山のfilter定義を強制するのも良くない気がする
- manifest.xmlに定義しなければならないintent.actionは1個だけ、が嬉しい
  - 実際のkeyの情報はputExtraのvalueに入れておけば良い
  - mediaボタン系だと`EXTRA_KEY_EVENT`のkeyにKeyEventオブジェクトをvalueとして対応させたりするらしい
  - 独自のkeyをKeyEventとして運用する場合はkey mappingのルールが必要になる
  - KeyEventでなく単なるstringでkeyを識別させても良い
    - こういう時はconst文字列の定義が欲しくなるが...余計なライブラリをapp.apkにリンクさせない方針の場合は運用ルールを守ってもらう程度しか出来ない

```plantuml
    state external
    state webAPI: keys/\n  power\n  play\n  stop
    state keyConverter: intent.action="~.extra.keys"\nputExtra(EXTRA_KEY_EVENT)
    state app.apk: intent-filter="~.extra.keys"\nBroadcastReceiver
    external -> webAPI: request
    webAPI --> keyConverter: request
    keyConverter -> app.apk: intent broadcast
```