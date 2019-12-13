# docker + docker-composeをlinuxにinstall
---
## dockerインストール手順
1. パッケージインデックスの更新
```
sudo apt-get update
```

2. 前提ソフトのインストール
```
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
```

3. docker公式GPG公開鍵のインストール
```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
```

4. aptリポジトリ設定(x86_64)
```
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
```

5. docker-ceのインストール
```
sudo apt-get update
sudo apt-get install -y docker-ce
```

6. 一般ユーザの実行権限付与
```
sudo usermod -aG docker $user
```

7. dockerサービス常時起動設定
```
sudo systemctl start docker
sudo systemctl enable docker
```

8. dockerコマンドテスト
```
docker -v
```

9. helloworldで動作確認
```
docker run hello-world
```

---
## docker-composeインストール手順
- [Releases · docker/compose · GitHub](https://github.com/docker/compose/releases)
	- downloadするdocker-composeのversionをリンク先で確認する
	- 新しい方が良さそうなので、2019.12.13時点でlatestとなっている1.25.0にする

1. docker-composeのdownload
```
sudo curl -L https://github.com/docker/compose/releases/download/1.25.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
```

2. 実行権限付与
```
sudo chmod +x /usr/local/bin/docker-compose
```

3. docker-comopseコマンドテスト
```
docker-compose -v
```

4. ~/docker/helloworld/docker-compose.ymlを用意
```
version: "3.7"
services:
  hello:
    image: hello-world:latest
```

5. helloworldで動作確認
```
docker-compose up
```
