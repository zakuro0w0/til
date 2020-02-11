# docker + python + FlaskでAPIサーバ

- [Docker + Python + FlaskでAPIサーバーを構築してみる \| UnaBlog](http://unalus.com/wp/2019/11/22/docker-python-flaskでapiサーバーを構築してみる/)
- [Flaskへ ようこそ — Flask v0.5.1 documentation](https://a2c.bitbucket.io/flask/)

## やりたいこと
- gitlabからMicrosoft TeamsにPOSTされる通知内容をカスタムしたい
- 既存のTeams連携では通知内容が貧弱
- gitlabからのPOSTを一旦受け取り、内容をカスタムした上でTeamsのwebhook URLにPOSTし直すAPIサーバが欲しい

## APIサーバの要件
- 環境構築に再現性を持たせたい >> docker
- コンパイルとか面倒なのでインタプリタ言語で >> python
- 出来ることは多くなくて良いので、軽量で小さく始められるサーバ >> Flask

## ディレクトリ構成とファイルの配置
.
├── custom_webhook/
│   ├── apache2/
│   │   └── sites-available/
│   │       └── 000-default.conf
│   ├── apihook/
│   │   ├── main.py
│   │   └── app.wsgi
│   └── DockerFile
├── docker-compose.yml
├── gitlab_etc/
├── gitlab_log/
├── gitlab_opt/
└── runner_config/

## custom_webhook/配下のファイル
### DockerFile
```
# Pythonは公式イメージ
FROM python:3.8.0

# 各ライブラリインストール
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y  vim sudo apache2 libapache2-mod-wsgi-py3

RUN pip3 install Flask

# default.confを修正
RUN rm /etc/apache2/sites-available/000-default.conf
COPY ./apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf

# default.confを修正
COPY ./apihook /home/vagrant/apihook

# Apache起動
EXPOSE 80
CMD ["apachectl", "-D", "FOREGROUND"]
```

### 000-default.conf
```
ServerName localhost:80
<VirtualHost *:80>
    WSGIDaemonProcess apihook processes=1 threads=5 python-path="/usr/local/bin/python3"
    WSGIScriptAlias / /home/vagrant/apihook/app.wsgi

    <Directory /home/vagrant/apihook>
        WSGIProcessGroup apihook
        WSGIApplicationGroup %{GLOBAL}
        Require all granted
    </Directory>
</VirtualHost>
```

### app.wsgi
```
import sys
sys.path.insert(0, '/usr/local/lib/python3.8/site-packages')
sys.path.insert(0, '/home/vagrant/apihook')

import os
# Change working directory so relative paths (and template lookup) work again
os.chdir(os.path.dirname(__file__))

from main import app as application
```

### main.py
- 関数のアノテーションでURIのルーティングとメソッド指定を行う
- POSTのbodyにあたるjsonデータは`request.get_data()`で取得できる
- python標準のprint()で`/var/log/apache2/error.log`に書き込まれる
- notify()でPOSTされたjsonデータを取り出し、Teamsで通知したい内容に加工した後、webhook URLにPOSTし直す必要がある
- POST方法は大まかに2通りだが、現時点ではcurlコマンドの方のみ上手く動かせている
	- urllib.request.urlopen()で投げる
	- subprocess.check_output()でcurlコマンドを直接叩く

```python
from flask import *
import urllib.request
import urllib.parse
import subprocess

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False

@app.route('/hello')
def hello():
    return 'Welcome! MyApp!'

@app.route('/func')
def func():
    return 'Welcome! MyFunction!'

webhook = 'https://outlook.office.com/webhook/xxxxx/IncomingWebhook/xxxx/xxxx'

@app.route('/notify', methods=['POST'])
def notify():
    print(request.headers)

    data = urllib.parse.urlencode({'Text':'test from apihook'}).encode('utf-8')
    headers = {'Content-Type': 'application/json'}
    req = urllib.request.Request(webhook, data, headers)
	response = urllib.request.urlopen(req)

    result = subprocess.check_output(["curl", "-X", "POST", "--data", "{\"Text\":\"TEST!!\"}", webhook])
    #result = subprocess.check_output(["curl", "-X", "POST", "--data", f"{\"Text\": {request.get_data()}}", webhook])
    #result = subprocess.check_output(["curl", "-X", "POST", "--data", json.dumps(jsonify("Text", request.get_data())), webhook])
    return request.get_data()

@app.route('/post', methods=['POST'])
def post():
    return request.get_data()
```

## docker-compose.yml
```yml
version: '3.7'
services:
    gitlab:
        image: gitlab/gitlab-ce:latest
        restart: always
        container_name: gitlab
        environment:
                GITLAB_OMNIBUS_CONFIG: |
                        nginx['custom_gitlab_server_config'] = "location /-/plantuml/ { \n    proxy_cache off; \n    proxy_pass  http://plantuml:8080/; \n}\n"
        volumes:
            - ./gitlab_etc:/etc/gitlab
            - ./gitlab_log:/var/log/gitlab
            - ./gitlab_opt:/var/opt/gitlab
        ports:
            - "10080:80"
            - "10022:22"
    runner:
        image: gitlab/gitlab-runner
        restart: always
        container_name: gitlab-runner
        volumes:
            - ./runner_config:/etc/gitlab-runner
            - /var/run/docker.sock:/var/run/docker.sock
        depends_on:
            - gitlab
    plantuml:
        image: 'plantuml/plantuml-server:tomcat'
        container_name: plantuml
    apihook:
        build:
            context: ./custom_webhook
            dockerfile: DockerFile
        container_name: apihook
        ports:
            - "8080:80"
        volumes:
            - ./custom_webhook/apihook/:/home/vagrant/apihook
```

## apihookを起動する
- docker-compose.ymlがある位置で下記コマンドを実行
```
docker-compose up -d
```

## apihookの動作確認
- dockerを起動しているホストPCから実行する場合
```
curl -X POST -d "{"key": 999}" "http://localhost:8080/post"
```

- apihookの中から実行する場合
```
docker exec -it apihook bash
```
```
curl -X POST -d "{"key": 999}" "http://localhost:80/post"
```

## main.pyへの変更を反映する
- apihookコンテナの中に入る
```
docker exec -it apihook bash
```
- apacheを再起動する
```
apachectl restart
```

## gitlabからapihookにPOSTさせる
- gitlab管理者ログイン
	- 管理者エリア >> 設定 >> ネットワーク >> Output requests
		- `Allow requests to the local network from web hooks and services`のcheckboxをON
		- `Whitelist to allow requests to the local network from hooks and services`↓のテキストボックスに通信を許可したいサーバの名前(今回はdocker-compose.ymlでserviceに指定した`apihook`)を追加
		- Save changes
	- リポジトリ設定 >> インテグレーション
		- Microsoft Teams Notificationは一旦停止しておく
		- webhook URLにapihookのURLを追加する >> `http://apihook/notify`

## gitlabからPOSTされるデータ
- [Webhooks \| GitLab](https://docs.gitlab.com/ee/user/project/integrations/webhooks.html#merge-request-events)
	- MRの場合は↑のjsonから欲しいデータを取得する

## TeamsにPOSTするデータ
- jsonの"Summary" or "Text"フィールドが必須となっている
- [従来のアクション可能メッセージ カード リファレンス - Outlook Developer \| Microsoft Docs](https://docs.microsoft.com/ja-jp/outlook/actionable-messages/message-card-reference)
	- 多分↑あたりを見ながら通知する内容を決めれば良い
