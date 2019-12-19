# android service

## サービスの定義
```kotlin
class MyService : Service(){
	override fun onBind(intent: Intent): IBinder{}
	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		// ToDo : start your service
		return super.onStartCommand(intent, flags, startId)
	}
}
```

## サービスの起動
```kotlin
class MainActivity : AppCompatActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        startService(Intent(this, MyService::class.java))
	}
}
```