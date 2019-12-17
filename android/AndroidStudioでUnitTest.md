# androidでUnitTest
- AndroidStudioにおけるクラスの単体テスト作成、実行、レポート確認までの手順をまとめる
---
## 実装
- テストしたいクラスを実装する
- 以下の例ではCalculatorクラスのsum(), multiply()関数を実装する

![9867d364.png](./attachments/de61a05a.png)

## テスト作成
1. テスト対象のクラス(Calculator)を選択
2. Ctrl + Shift + T >> 新規テストの作成

![d4ae5c13.png](./attachments/d4ae5c13.png)


3. 次のテスト・メソッドを作成 >> テストを作る関数にチェックON

![1dca980a.png](./attachments/7578bfe5.png)


4. android UIに関係の無いテストはandroidTestではなくtest配下へ

![89cd0b9d.png](./attachments/89cd0b9d.png)


5. テストのスケルトンが自動生成される

![42f33673.png](./attachments/42f33673.png)


6. assertEquals()等でテストを実装する

![c64c5241.png](./attachments/c64c5241.png)


## テスト実行(AndroidStudio UIから)
- プロジェクトエクスプローラで対象となるファイル(CalculatorTest)を右クリック
- 実行(U) 'CalculatorTest'

![bdf139ea.png](./attachments/bdf139ea.png)


- もしくは対象となるテストクラス名を右クリック
- 実行(U) 'CalculatorTest'

![5b5aeb17.png](./attachments/5b5aeb17.png)

## テスト実行(コマンドから)
- AndroidStudioのターミナル等から以下のコマンドで単体テストを実行できる

```
graldew test
```

- クラスを指定して実行したい場合は以下の通り
	- ビルドバリアント値 : "Debug" or "Release" が入る

```
gradlew test{ビルドバリアント値}UnitTest --tests {テストクラス名}
```

- DebugビルドしたCalculatorTestクラスの単体テストを実行する場合
```
gradlew testDebugUnitTest --tests CalculatorTest
```

![54397875.png](./attachments/76aed38b.png)


## テストレポートを確認
- `{projectRoot}/app/build/reports/tests/testDebugUnitTest/index.html`に出力される

![3d27b8e9.png](./attachments/3d27b8e9.png)

---
![07bc06b6.png](./attachments/07bc06b6.png)

---
![6aa48c83.png](./attachments/5c4f2650.png)

