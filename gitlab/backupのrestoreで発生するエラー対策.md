# gitlab restore時のundefined method 'root_of_fork_network'エラー対策


## 現象
- gitlabのbackupをrestoreする(`gitlab-backup restore BACKUP=....`)を実行した時に以下のエラーが出てrestoreが失敗する
	- restoreが失敗するため、backupが意味を成さなくなる
- [GitLab restore backup looks successful but with error message (#221296) · Issues · GitLab.org / GitLab · GitLab](https://gitlab.com/gitlab-org/gitlab/-/issues/221296)

```
2020-06-11 20:51:26 -0400 -- done
2020-06-11 20:51:26 -0400 -- Restoring repositories ...
 * application/xxxx ... [DONE]
 - Object pool @pools/6b/86/6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b...
rake aborted!
NoMethodError: undefined method `root_of_fork_network' for nil:NilClass
/opt/gitlab/embedded/service/gitlab-rails/lib/backup/repository.rb:167:in `block in restore_object_pools'
/opt/gitlab/embedded/service/gitlab-rails/lib/backup/repository.rb:164:in `restore_object_pools'
/opt/gitlab/embedded/service/gitlab-rails/lib/backup/repository.rb:106:in `restore'
/opt/gitlab/embedded/service/gitlab-rails/lib/tasks/gitlab/backup.rake:106:in `block (4 levels) in <top (required)>'
/opt/gitlab/embedded/service/gitlab-rails/lib/tasks/gitlab/backup.rake:73:in `block (3 levels) in <top (required)>'
/opt/gitlab/embedded/bin/bundle:23:in `load'
/opt/gitlab/embedded/bin/bundle:23:in `<main>'
Tasks: TOP => gitlab:backup:repo:restore
(See full trace by running task with --trace)
```

## 原因
- forkしたリポジトリのfork元を先に削除したことで、gitlabのpool repositoryにゴミが残ったこと

## 前提知識
- gitlabコンテナの/var/opt/gitlab/git-data/repositories/配下にリポジトリ関連のデータが格納される
	- @hashed/配下には作成したリポジトリが格納される
		- ディレクトリパスはSHA256のhash値で表現される
		- どのリポジトリのパスなのかはgitlab管理者メニューのproject詳細から確認できる
		- リポジトリを削除した場合、ディレクトリパスに+deletedが付与される
	- @pools/配下にはforkしたリポジトリ関連のデータが格納される
		- 1個forkすると@pools/配下にディレクトリが増える

## この状態にならないために...
- プロジェクト運用としてforkを禁止するか
- あるいはfork元を消さないルールにするか

## 正しくrestoreさせる方法
### gitlabコンテナにログインする
```
docker exec -it mygitlab.com bash
```

### リポジトリデータのある直上まで移動
```
cd /var/opt/gitlab/git-data/repositories/
```

### @pools配下のディレクトリパスを一覧表示させる
- treeが無ければlsでも何でもOK
```
tree -L 4
```

```
└── @pools
    ├── 4b
    │   └── 22
    │       └── 4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a.git
    ├── 4e
    │   └── 07
    │       └── 4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce.git
    ├── 6b
    │   └── 86
    │       └── 6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b.git
    ├── d4
    │   └── 73
    │       └── d4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35.git
    └── ef
        └── 2d
            └── ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d.git
```

### @pools配下のディレクトリ名からgitaly上のidを調べる
- `.git`の前にある文字列はSHA256のhash値であり、これをdecodeすることでDB上のidを調べることが出来る
- [Sha256 Decrypt & Encrypt - More than 15.000.000.000 hashes](https://md5decrypt.net/en/Sha256/)
	- 例えば`4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a`を↑のサイトでDecryptすると`4`であることが分かる

![bb4564f2.png](:storage\815f03b7-db73-4d6d-8e73-63e3fdf30ab1\bb4564f2.png)


### 調べたidからfork元の有無を調べる
- gitlabコンテナにログインした状態でrails consoleを起動する
```
gitlab-rails c
```
- rails consoleを起動すると以下のようなirbのプロンプトが表示される
	- 以降のコマンドはこのirbプロンプト上で実行していく
	- rails consoleを終了する時は`exit`コマンドを実行する
```
root@gitlab:/var/opt/gitlab/git-data/repositories# gitlab-rails c
--------------------------------------------------------------------------------
 GitLab:       12.8.5-ee (ff0a9cb094f) EE
 GitLab Shell: 11.0.0
 PostgreSQL:   10.12
--------------------------------------------------------------------------------
Loading production environment (Rails 6.0.2)
irb(main):001:0>

```

- SHA256のdecryptで調べたidを元に、poolオブジェクトを取得する
```
pool = PoolRepository.find_by_id(4)
```
- `find_by_id()`実行結果として取得したpoolオブジェクトの`source_project`が表示される
	- これはfork元の親リポジトリがどれか、を示している
	- これが現存するリポジトリであれば、そのpoolオブジェクトは健全な状態
```
irb(main):001:0> pool = PoolRepository.find_by_id(4)
=> #<PoolRepository id:4 state:ready disk_path:@pools/4b/22/4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a source_project: path/to/repository>
irb(main):002:0>
```

- 以下のように`source_project`が`nil`の場合はfork元が既にいない状態となっている
	- このpoolオブジェクトがrestoreを阻害している原因となる
```
irb(main):002:0> pool = PoolRepository.find_by_id(1)
=> #<PoolRepository id:1 state:ready disk_path:@pools/6b/86/6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b source_project: nil>
irb(main):003:0>
```

### fork元のいないpoolオブジェクトを破棄する
- `find_by_id()`で`source_project`がnilになっているオブジェクトをpoolに確保した状態で`destroy!`を実行する
```
pool.destroy!
```

- ここまででrails console上の作業は終了
```
exit
```

### 改めてgitlabのbackupを取得する
- `pool.destroy!`までの手順を踏んだ上でbackupを取り直さないといけない
	- ので、半年前のbackupが壊れてた！の場合だと復元は難しい
	- 最新の状態のbackupを正しく取れるようにすることは出来るが、過去のbackupも正しく復元できるようにはならない
```
gitlab-backup create
```