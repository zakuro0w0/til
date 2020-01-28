# GitLab + PlantUML

- [PlantUML & GitLab \| GitLab](https://docs.gitlab.com/ce/administration/integration/plantuml.html)
- [GitLab を PlantUML に対応させる\|へっぽこプログラマーの備忘録](http://kuttsun.blogspot.com/2017/10/gitlab-plantuml.html)

```:docker-compose.yml
vcs@flc-vcs:~/docker/gitlab$ cat docker-compose.yml
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
```



- gitlabに追加したenvironmentの説明
	- `http://localhost:9000/-/plantuml/`へのアクセスを`http://plantuml:8080`に飛ばすよ
	- gitlab UIから設定するplantumlのactivateでは外から見た時のplantumlの場所を指定する必要がある
		- 外から見た時のURLはport forwarding設定により変わるんだが...
		- external URLをplantumlに設定するべきか
```
environment:
	GITLAB_OMNIBUS_CONFIG: |
		nginx['custom_gitlab_server_config'] = "location /-/plantuml/ { \n    proxy_cache off; \n    proxy_pass  http://plantuml:8080/; \n}\n"
```


![plantuml_url.png](./images/plantuml_url.png)