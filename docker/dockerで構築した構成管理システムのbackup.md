# gitlab含む構成管理システムのbackup

## docker volumeのハマりポイント
- ホストとコンテナ間のデータ共有にはディレクトリマウントとvolumeマウントがある
	- ディレクトリマウントはlinux限定で、windowsでは動かない
	- ホスト側のディレクトリをコンテナにマウントさせる設定を紹介している記事は暗黙にlinux前提であるため、windowsでは再現できない
- コンテナ内の特定のディレクトリを後からdocker volumeにマウントさせることは可能である
	- つまり、最初はbackup対象として認識できていなくても、後からvolumeマウントを追加することでbackup対象にすることが可能

## docker volumeのbackup
- [【Docker】具体例で理解するデータボリュームのバックアップ・リストア方法 \| Enjoy IT Life](https://nishinatoshiharu.com/docker-volume-backup/)
- ↓のコマンド解説
	- backupしたいvolumeを軽量なコンテナ(busybox)にmountさせ、tarコマンドでbackup.tarを生成し、ホスト側のカレントディレクトリにbackup.tarを残す
	- busyboxは一時的にマウントするためのコンテナなので、終わり次第即時削除する(`--rm`オプション)
	- ホスト側のディレクトリをマウントさせるため、これはlinux限定、windowsではbackup.tarがホスト側に残らない
		- `--rm`オプションを外してコンテナを即時削除せず、`docker cp`でコンテナからbackup.tarを取り出せばwindowsでも可能
	- {volume_name}: backup対象となるdocker volumeの名前、`docker volume ls`で確認できる
	- {volume_mount_path}: backup対象となるdocker volumeがコンテナのどこにmountされているか、これはdocker-compose.ymlで確認できる

### docker-compose.yml
```yml
version: '3.7'
services:
    gitlab:
        build:
            context: .
            dockerfile: Dockerfile_gitlab
        restart: always
        container_name: mygitlab.com
        hostname: 'mygitlab.com'
        environment:
			# gitlab内部にbackup関連の設定項目もあった
			# が、backupをスケジューリングできる訳ではなく、どこに作るかといった設定のみ
			# スケジューリングのためにはホスト側のcron等による定期処理が必要
            GITLAB_OMNIBUS_CONFIG: |
                gitlab_rails['manage_backup_path'] = true
                gitlab_rails['backup_path'] = "/var/opt/gitlab/backups"
                gitlab_rails['backup_archive_permissions'] = 0644
                gitlab_rails['backup_keep_time'] = 604800
        ports:
            - "10080:80"
        volumes:
			# gitlabの設定backupは/etc/gitlab/
            - gitlab_etc:/etc/gitlab
    runner:
        image: gitlab/gitlab-runner
        restart: always
        container_name: gitlab-runner
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock
        depends_on:
            - gitlab
    nexus:
        image: sonatype/nexus3
        hostname: mynexus.com
        container_name: mynexus.com
        restart: always
        ports:
            - "8081:8081"
        volumes:
			# nexusはバイナリリポジトリとして稼働するため、jarやapkのbackupが必要
			# data volumeをbackup対象のディレクトリにマウントする
            - nexus_data:/nexus-data/
volumes:
	# external: trueとしたvolumeはdocker-compose upの前に
	# docker volume createで作成しておく必要がある
    gitlab_etc:
        external: true
    gitlab_opt:
        external: true
    gitlab_log:
        external: true
    nexus_data:
        external: true
```

### data volume backup
```shell
docker run --rm -v {volume_name}:{volume_mount_path} -v 'pwd':/backup busybox tar cvf /backup/backup.tar {volume_mount_path}
```


## gitlabのbackup
- 2種類のbackupが必要で、アプリケーションデータは単純にdocker volumeではbackupできなさそう
- [Backing up and restoring GitLab \| GitLab](https://docs.gitlab.com/ee/raketasks/backup_restore.html)
- [Dockerで立ち上げたGitLabの定期バックアップ方法 - Qiita](https://qiita.com/TomoyukiSugiyama/items/e9da7c873654cb86a14d)

### gitlabアプリケーションデータのbackup
- ↓のコマンドでgitlabコンテナ内に`/var/opt/gitlab/backups/xxx_yyyy_mm_dd_{gitlab-version}_gitlab_backup.tar`が生成される
```shell
docker exec -t {conrainer_name} gitlab-backup create
```

### gitlab設定ファイルのbackup
- /etc/gitlab/配下のアーカイブファイルも完全なbackupに必要となる
- /etc/gitlab/をdocker volumeでmountしている場合は既に永続化できているが、念のためbackupは取っておいた方が良い
```shell
docker exec -t {container_name} tar -cvzf /var/opt/gitlab/backups/gitlab_config.tgz /etc/gitlab/
```

### gitlab backupで生成したアーカイブファイルをホストに取り出す
- 上記のbackupコマンドはいずれもgitlabコンテナ内に結果を出力するため、これをホスト側に取り出す必要がある
```shell
docker cp {container_name}:/var/opt/gitlab/backups/ .
```

## [gitlabのrestore](https://docs.gitlab.com/ee/raketasks/backup_restore.html#restore-for-omnibus-gitlab-installations)

### ハマりポイント
- 復元先となる新しいgitlabコンテナを用意する時、docker imageのバージョンは復元元と完全に一致していないとダメ
- gitlabアプリケーションデータを`gitlab-backup create`で作成した際、tarファイル名にはimageのバージョンも含まれるのでそこと合わせること

### backupしたアーカイブファイルを復元先コンテナにコピーする
- `/var/opt/gitlab/backups/xxxxxx_yyyy_mm_dd_{gitlab-version}_gitlab_backup.tar`
- `/etc/gitlab_config.tgz`
	- こっちのtgzは解凍し、gitlab/ディレクトリを上書きすること

### gitlabアプリケーションデータの復元
```shell
sudo chown git.git /var/opt/gitlab/backups/11493107454_2018_04_25_10.6.4-ce_gitlab_backup.tar
sudo gitlab-ctl stop unicorn
sudo gitlab-ctl stop puma
sudo gitlab-ctl stop sidekiq
sudo gitlab-ctl status
sudo gitlab-backup restore BACKUP=11493107454_2018_04_25_10.6.4-ce
```

### gitlab設定データの復元
```shell
sudo gitlab-ctl reconfigure
sudo gitlab-ctl restart
sudo gitlab-rake gitlab:check SANITIZE=true
```

## nexusのbackup
- nexusはmavenリポジトリとして振る舞い、jarやapkを保存するためbackupは必須
- nexusコンテナ内の`/nexus-data/`をvolumeにmountさせておけばOK
- backup方法はこの記事先頭のdocker volumeのbackup方法を参照

## backupのスケジューリング
- 構成管理システムのホストマシンがlinuxであるという前提で、cronを使うものとする
	- windowsの場合は別途同等の定期実行する仕組みを利用してもらう必要がある

### /etc/cron.d/vcs_backup
```shell
## 毎日深夜2時にbackup.shを実行する
0 2 * * * {filepath}/backup.sh CRON=1
```

### backup.sh
```shell
#!/bin/bash
## gitlabアプリケーションデータのbackup作成
docker exec -t {gitlab_conrainer_name} gitlab-backup create
## gitlab設定ファイルのbackup作成
docker exec -t {gitlab_conrainer_name} tar -cvzf /var/opt/gitlab/backups/$(date "+%s_%Y_%m_%d_%H_%M_%S_gitlab_config.tgz") /etc/gitlab/
## gitlab backupファイルを所定の位置に取り出す
docker cp {gitlab_conrainer_name}:/var/opt/gitlab/backups/ {destination_path}
## gitlabコンテナ内のbackupで1週間以上経過した古いファイルを削除する
docker exec -t {gitlab_container_name} find /var/opt/gitlab/backups -mtime +6 | xargs rm -rf

## nexusに保存したjar等バイナリのbackup作成
docker exec -t {nexus_container_name} tar -cvzf /var/opt/$(date "+%s_%Y_%m_%d_%H_%M_%S_gitlab_config.tgz") /nexus-data/
## nexus backupファイルを所定の位置に取り出す
docker cp {nexus_container_name}:/var/opt/ {destination_path}
## nexusコンテナ内のbackupで1週間以上経過した古いファイルを削除する
docker exec -t {nexus_container_name} find /var/opt/ -mtime +6 | xargs rm -rf
```