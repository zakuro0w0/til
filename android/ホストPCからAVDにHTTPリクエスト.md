# ホストPCからAVD(エミュレータ)にHTTPリクエストを投げる
---
## やりたいこと
- ホストPCであるWindowsのchromeブラウザやRestClientからAVDにHTTPリクエストを投げたい

## 前提条件
- AVDではWebServerが8080ポート等をlistenしていること
- ホストPCでadbコマンドが使えること

## 手順
1. AVDでWebServerを起動
2. ホストPCでポートのリダイレクト設定
	- [外部からAndroidエミュレータへTCPまたはUDPで通信する方法 - 日記のような何か](https://learnin.hatenablog.com/entry/20110625/p1)
	- powershellやAndroidStudioのターミナルでadbコマンドを使う
	- AVDを再起動した場合は再びadbコマンドによるリダイレクト設定が必要

```:ポートのリダイレクト設定コマンド
adb forward tcp:{ホストPCの転送元ポート番号} tcp:{AVDがlistenするポート番号}
```

```:ホストの18080ポートをAVDの8080ポートに転送する例
adb forward tcp:18080 tcp:8080
```

3. ホストPCのブラウザURLに`http://localhost:18080`でAVDの`http://localhost:8080`にアクセスできる
4. [Advanced REST Client](https://install.advancedrestclient.com/install)等を使えばGET以外のHTTPメソッドもリクエスト可能
	- [Advanced REST client(ARC)のインストールとJSONを送信するサンプル \| ITSakura](https://itsakura.com/tool-arc-json)

