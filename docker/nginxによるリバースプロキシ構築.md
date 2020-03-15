# nginx on dockerでリバースプロキシを構築する

## やりたいこと
- windowsのブラウザからポート番号無しのURLでdockerコンテナにアクセスしたい
- アクセスしたいdockerコンテナがwindows上ではなく踏み台の先にあるリモート環境の場合、sshトンネルを経由したアクセスになる
    - この時windowsの`localhost:{sshトンネルのポート番号}`というアクセスになるが、このポート番号を省略したアクセスにしたい
- ※踏み台アクセス先のリモート環境にはgitlabコンテナとmavenコンテナがあり、ローカル環境から見たmavenと、gitlabコンテナから見たmavenが同じURLでアクセスできないと困る事情がある

## ディレクトリ構成とファイル配置
```
.
├── default.conf
└── docker-compose.yml
```

## docker-compose.yml
```yml:docker-compose.yml
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
    maven:
        image: nginx:latest
        container_name: mymaven
        ports:
            - "7777:80"
    # リバースプロキシとして働くnginxサーバ
    nginx-proxy:
        image: nginx:latest
        container_name: myproxy
        ports:
            - "80:80"
        volumes:
            - ./default.conf:/etc/nginx/conf.d/default.conf
```

## /etc/nginx/conf.d/default.conf

```conf:default.conf
# nginxのconfファイルは末尾にセミコロンが無いとコンテナ起動に失敗する
server {
    listen 80;
    # nginxのサーバ名(ホストPCのhostsファイルで名前解決しておくこと)
    server_name mygitlab.com;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Server $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    # "http://mygitlab.com"へのアクセスに対してどうするかを設定する
    location / {
        # 以下、proxy_passによる転送の設定
        ## 同じdockerネットワーク内の別のコンテナ(gitlab)に転送する
        # proxy_pass http://gitlab;
        ## ホストPC(host.docker.internal)の指定ポート番号に転送する
        proxy_pass http://host.docker.internal:10080;
    }
}


server {
    listen 80;
    # nginxのサーバ名(ホストPCのhostsファイルで名前解決しておくこと)
    server_name mymaven.com;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Server $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    # "http://mymaven.com"へのアクセスに対してどうするかを設定する
    location / {
        # 以下、proxy_passによる転送の設定
        ## 同じdockerネットワーク内の別のコンテナに転送する
        # proxy_pass http://mydummy;
        ## ホストPC(host.docker.internal)の指定ポート番号に転送する
        proxy_pass http://host.docker.internal:7777;
    }
}
```

## C:\\Windows\System32\driver\etc\hosts

```:hosts
127.0.0.1 localhost
127.0.0.1 mygitlab.com
127.0.0.1 mymaven.com
```

alias dc='docker-compose'
alias dcon='docker container $1'
alias docker='docker.exe'
alias docker-compose='docker-compose.exe'



