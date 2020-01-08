# Android Homeアプリ
- [超シンプルなホームアプリ（ランチャーアプリ）を作る - Qiita](https://qiita.com/ryo_mm2d/items/00326b0d8f088975fa0e)
	- ViewHolderとAdapterはRecyclerViewのものなので注意
- [AndroidのListViewやRecyclerViewの、ViewHolderやDataBindingを調べた記録 - Qiita](https://qiita.com/paming/items/b06a54632a0432923122)
- [[Android] RecyclerView の基本的な設定](https://akira-watson.com/android/recyclerview.html)
- [RecyclerViewはListViewの代替ではないよねという話 - visible true](http://sys1yagi.hatenablog.com/entry/2015/01/09/090000)
- ListViewで済む場合はRecyclerViewよりも簡単
	- 柔軟にカスタムしたい場合はRecyclerViewを使う必要がある

#### アプリのHome化
```:AndroidManifest.xml
<activity android:name=".MainActivity">
	<intent-filter>
		<action android:name="android.intent.action.MAIN" />
		<category android:name="android.intent.category.HOME" />
		<category android:name="android.intent.category.DEFAULT" />
		<category android:name="android.intent.category.LAUNCHER" />
	</intent-filter>
</activity>
```