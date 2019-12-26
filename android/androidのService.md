# android service

## background serviceの起動
```kotlin
class MyService : Service(){
	override fun onBind(intent: Intent): IBinder{}
	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		// ToDo : start your service
		return super.onStartCommand(intent, flags, startId)
	}
}
```

```kotlin
class MainActivity : AppCompatActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        startService(Intent(this, MyService::class.java))
	}
}
```

## foreground serviceの起動
- Serviceをforegroundで起動させる
- 通知を出す代わりにbackgroundの制約を受けなくなる
- Serviceを起動したActivityがonPauseでbackgroundに回ってもService::onDestroyされなくなる
	- 完全に永続化できている訳ではないと思う、過信は禁物

```:AndroidManifest.xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

```kotlin
override fun onCreate(savedInstanceState: Bundle?){
	//...
	startForegroundService(Intent(this, MyService::class.java))
}
```

```kotlin
override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
	val channelId = "myService_foreground"
	
	// 通知用のchannelを作っておく必要がある
	(getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).let{ manager->
		manager.getNotificationChannel(channelId)?: let{
			val name = "通知のタイトル的な情報"
			NotificationChannel(channelId, name, NotificationManager.IMPORTANCE_DEFAULT).let{ channel->
				channel.description = "この通知の詳細な説明"
				manager.createNotificationChannel(channel)
			}
		}
	}

	// startForegroundService()から5秒以内に実行しないと例外でcrashする
	// createNotificationChannel()で使ったchannelIdを指定しないといけない
	startForeground(1, NotificationCompat.Builder(this, channelId).apply{
		setContentTitle("this is notification title")
		setContentText("this is notification text")
	}.build())

	return START_STICKY
}
```