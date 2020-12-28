# AndroidStudioプロジェクトに動画ファイルをリソースとして追加する

## やりたいこと
- タイトルのまま
- 画像リソースはリソースマネージャから追加する手順が紹介されてるのをよく見かける
- 動画リソースについては見つけられなかったのでここでまとめておく

## 手順

### rawディレクトリを追加する

![](attachments/2020-12-28-13-11-07.png)

![](attachments/2020-12-28-13-11-17.png)

### rawディレクトリに動画ファイルをコピーする

![](attachments/2020-12-28-13-13-26.png)

![](attachments/2020-12-28-13-12-30.png)

### コードから動画リソースファイルを参照する
- `myvideo.mp4`なら、`R.raw.myvideo`でアクセス可能
- VideoView等にリソースのファイルパスを渡す場合は以下のようになる
    - [VideoViewでres/drawable内のファイルを再生する](https://qiita.com/ikneg_/items/63ac2966bf226934463b)

```kotlin
videoView.setVideoPath("android.resource://${this.getPackageName()}/${R.raw.myvideo}")
```