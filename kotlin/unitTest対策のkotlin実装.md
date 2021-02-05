# unitTest対策のkotlin実装
- junitでunitTestを書くに当たって注意した方が良いトピックをまとめる

## カバレッジ測定ツールjacocoの仕様を知っておく
- jacocoはAndroidStudioに標準で搭載されている
- jacocoはJavaの時代から使われており、kotlinにも対応している
- しかし、jacocoがカバレッジを測定するのはkotlinコードではなく、kotlinコードから生成したjavaコードであることに注意が必要
- kotlinコード上では分岐を全て網羅していても、javaコードではそうでない場合が多い
- 真面目な開発者はAndroidStudioでkotlinバイトコードを逆コンパイルし、javaコードを見てカバレッジを何とか網羅しようとする
    - が、それではjacocoに振り回されてしまうので、ある程度の割り切りが必要になる
- 2021.02時点では他にカバレッジツールの選択肢が無い状態
    - IntelijIDEAのカバレッジランナーはCLIに対応しておらず、CIで使えない
