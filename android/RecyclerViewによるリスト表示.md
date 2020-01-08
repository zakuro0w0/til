# RecyclerViewによるリスト表示
## RecyclerView
- 2020.01現在ではandroidx.recyclerviewを使う
	- 古い記事だとv7.supportとかを紹介しているので注意

```:module/build.gradle
dependencies{
	implementation 'androidx.recyclerview:recyclerview:1.0.0'
}
```

- メイン画面にRecyclerViewを配置する

```xml:activity_main.xml
<LinearLayout
	android:layout_width="match_parent"
	android:layout_height="wrap_content"
	android:orientation="vertical">

	<androidx.recyclerview.widget.RecyclerView
		android:id="@+id/myRecyclerView"
		android:scrollbars="vertical"
		android:layout_width="match_parent"
		android:layout_height="match_parent"/>
</LinearLayout>
```

## RecyclerViewに並べる1行分のデータ構造
- row.xmlがRecyclerView上に沢山並ぶことになる

```xml:row.xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:orientation="vertical"
    android:layout_width="match_parent"
    android:layout_height="wrap_content">
    <ImageView
        android:id="@+id/icon"
        android:layout_width="48dp"
        android:layout_height="48dp"
        android:layout_marginStart="8dp"
        android:layout_marginTop="8dp"
        android:layout_marginBottom="8dp"
        app:layout_constraintBottom_toBottomOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintTop_toTopOf="parent"
        tools:ignore="ContentDescription"
        tools:srcCompat="@drawable/ic_launcher_background"
        />
</LinearLayout>
```

- 1行分のデータ構造をAppInfoとして定義する
- 今回はアプリランチャー風のリストを作るのでアプリのアイコン、名前等を持たせる

```kotlin:AppInfo.kt
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable

data class AppInfo(
    val icon: Drawable,
    val label: String,
    val componentName: ComponentName){
	
	// アプリアイコンをクリックした時にアプリを起動させる処理
    fun launch(context: Context){
        Intent(Intent.ACTION_MAIN).let{ intent->
            intent.flags += Intent.FLAG_ACTIVITY_NEW_TASK
            intent.addCategory(Intent.CATEGORY_LAUNCHER)
            intent.component = componentName
            intent.resolveActivity(context.packageManager)?.run{
                context.startActivity(intent)
            }
        }
    }
}

// ランチャーに並ぶアプリ一覧を取得する
fun create(context: Context): List<AppInfo> {
    val pm = context.packageManager
    val intent = Intent(Intent.ACTION_MAIN)
        .also { it.addCategory(Intent.CATEGORY_LAUNCHER) }
    return pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        .asSequence()
        .mapNotNull { it.activityInfo }
        .filter { it.packageName != context.packageName }
        .map {
            AppInfo(
				// 参考にした記事ではnull時にgetDefaultIcon(this)を使っていたがcomileErrorになった
                it.loadIcon(pm)?: context.resources.getDrawable(R.drawable.ic_launcher_foreground),
                it.loadLabel(pm).toString(),
                ComponentName(it.packageName, it.name)
            )
        }
        .sortedBy { it.label }
        .toList()
}
```

## Adapter
- AdapterはRecyclerViewの方を使う、他にも別のクラスのAdapterがあるので注意
- AppViewHolderはlayout/row.xmlの1行分データ構造と対応させる(R.id.iconとか)

```kotlin:AppAdapter.kt
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import androidx.recyclerview.widget.RecyclerView

class AppAdapter(
    private val inflater: LayoutInflater,
    private val list: List<AppInfo>,
    private val onClick: (view: View, info: AppInfo) -> Unit
) : RecyclerView.Adapter<AppAdapter.AppViewHolder>() {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): AppViewHolder =
		// 1行分のデータ構造であるrow.xmlのレイアウトを対応させる
        AppViewHolder(inflater.inflate(R.layout.row, parent, false))

    override fun getItemCount(): Int = list.size

    override fun onBindViewHolder(holder: AppViewHolder, position: Int) {
        val info = list[position]
        holder.itemView.setOnClickListener { onClick(it, info) }
        holder.icon.setImageDrawable(info.icon)
//        holder.label.text = info.label
//        holder.packageName.text = info.componentName.packageName
    }

    class AppViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val icon: ImageView = itemView.findViewById(R.id.icon)
//        val label: TextView = itemView.findViewById(R.id.label)
//        val packageName: TextView = itemView.findViewById(R.id.packageName)
    }
}
```

## RecyclerViewとAdapterを紐付ける
- 1行分のデータ構造のリストからAdapterを生成
- AdapterとRecyclerViewを紐付ける
- RecyclerViewのレイアウトをLayoutManagerで指定する

```kotlin:MainActivity.kt
class MainActivity : AppCompatActivity() {
	fun initAppList(){
		// activity_main.xmlのRecyclerViewを取得して設定
        findViewById<RecyclerView>(R.id.myRecyclerView).let{ rv->
            rv.setHasFixedSize(true)
			// ここでアプリ一覧を持ったAdapterとRecyclerViewを紐付ける
            rv.adapter = AppAdapter(layoutInflater, create(this)) { view, info ->
				// onClick処理でアプリを起動する
                info.launch(this)
            }
			// LinearLayoutではorientationに対応した一方向に並べる
			// GridLayoutManagerでは格子状の区切りに並べることも可能らしい
            rv.layoutManager = LinearLayoutManager(this)
        }
    }
}
```