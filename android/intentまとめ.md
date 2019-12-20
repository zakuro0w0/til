# intent

## 明示的intentでアプリを起動する
- package名とclass名を指定し、ただ1つのアプリを起動する
- 起動する相手のことを知っている必要がある

### 起動される側
- packageはcom.example.clientと仮定する
- 起動するActivityのandroid:exportedをtrueにしておく

```xml:AndroidManifest.xml
<activity android:name=".MainActivity" android:exported="true">
	<intent-filter>
		<action android:name="android.intent.action.MAIN" />
		<category android:name="android.intent.category.LAUNCHER" />
	</intent-filter>
</activity>
```

### 起動する側
- UIスレッド上で明示的intentを作り、startActivity()に渡す
- intentには起動対象Activityのpackage名とclass名が必要
- Intent.flagsはIntent.FLAG_ACTIVITY_NEW_TASKでなければならないっぽい
	- NEW_TASKはデフォルト値なので何も設定する必要は無い
	- SINGLE_TOPを指定するとstartActivity()で例外が出る

```kotlin
fun test(){
	Intent().apply{
		// 第1引数に相手のpackage名
		// 第2引数に相手のpacakge名の完全修飾を含む起動対象Activityのclass名
		// ※class名だけだとresolveActivity()で失敗する
		setClassName("com.example.client", "com.example.client.MainActivity")
	}.let{
		// intentを受け取れるActivityが存在するか確認する
		if(it.resolveActivity(packageManager) != null){
			startActivity(intent)
		}
	}
}
```

## 暗黙的intentでアプリを起動する
- intent-filterで指定した条件に合致する不特定多数のアプリを起動する
- 起動する相手のことを知らなくても良い

### 起動される側
- `<intent-filter>`タグを追加する
- category.DEFAULTは必須なので忘れずに
- manifestを変更したらAVDや実機への再インストールも忘れずに
	- AndroidManifest.xmlをAndroidStudio以外で開いたままビルド＆AVDにインストールとかするとmanifest変更が反映されずにハマる、かも知れない

```xml:AndroidManifest.xml
<activity android:name=".MainActivity">
	<intent-filter>
		<action android:name="android.intent.action.MAIN" />
		<category android:name="android.intent.category.LAUNCHER" />
	</intent-filter>
	<!-- 受け取るfilter条件毎に<intent-filter>タグを追加する -->
	<intent-filter>
		<!-- action名は既定 or 独自どちらも選択可能 -->
		<action android:name="/apps/myapplication" />
		<!-- ↓のcategory.DEFAULTは暗黙的intent受け取りに必須 -->
		<category android:name="android.intent.category.DEFAULT" />
	</intent-filter>
</activity>
```

### 起動する側
- intentのaction名に"起動される側が待ち受けているaction"を指定するだけ

```kotlin
fun test(){
	Intent("/apps/myapplication").let{
		if(it.resolveActivity(packageManager) != null){
			startActivity(it)
		}
	}
}
```

## 起動済みActivityに暗黙intentを送信する
### startActivity()でアプリを起動する場合
```kotlin
fun test(){
	// 自前で定義したactionで暗黙intentを作る
	Intent("myaction").apply{
		// startActivity()に渡すintentなのでNEW_TASK必須
		flags += Intent.FLAG_ACTIVITY_NEW_TASK
	}.let{
		// intentを受け取れるActivityがいるかチェック
		if(it.resolveActivity(packageManager) != null){
			// Activityを起動する
			startActivity(it)
		}
	}
}
```

### sendBroadcast()で起動済みアプリに送信する場合
- resolveActivity()がチェックしているのは、恐らくAndroidManifest.xmlの`<IntentFilter>`で暗黙intentの受け取りを定義したActivityが存在するか否か
	- だからresolve()出来なかったと思われる
- 起動済みアプリへの暗黙intent送信ではresolveActivity()によるチェックが要らない

```kotlin
fun test(){
	Intent("myaction").let{
		// resolveActivity()によるチェックは不要
		sendBroadcast(it)
	}
}
```

## BroadcastReceiver::onReceive()から暗黙intentを送信する
- UIスレッドで実行させるためのHandler.postは不要
- onReceive()引数のcontextを使ってsendBroadcast()すればOK

```kotlin
class MyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
		Intent("myaction").let{
			context.sendBroadcast(it)
		}
    }
}
```