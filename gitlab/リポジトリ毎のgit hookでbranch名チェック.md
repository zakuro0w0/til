# リポジトリ毎にbranch名のチェックを行うgit hook

## やりたいこと
- リポジトリにpushされるbranch名をチェックし、条件を満たさないものを拒否したい
- global hookだと適用したくないリポジトリにまで影響が出るため、リポジトリ個別hookで対応したい

## gitlabコンテナのgit hookの位置
- 全リポジトリに共有させるhookは↓

```:global_git_hook
/opt/gitlab/embedded/service/gitlab-shell/hooks
```

- 個別のリポジトリに適用するhookは↓
	- `@hashed/`以下のパスはgitlab管理者メニュー >> プロジェクト詳細から確認可能

```:repository_git_hook
/var/opt/gitlab/git-data/repositories/@hashed/78/5f/785f3ec7eb32f30b90cd0fcf3657d388b5ff4297f2f9716ff66e9b69c05ddd09.git/hooks
```

## リポジトリ毎のgit hook設定
- [Server hooks \| GitLab](https://docs.gitlab.com/ee/administration/server_hooks.html#chained-hooks)

- gitlabコンテナのリポジトリ配下まで移動し、`custom_hooks`ディレクトリを作成
	- `chown git:root custom_hooks`で持ち主を変えておく
```
root@gitlab:/var/opt/gitlab/git-data/repositories/@hashed/78/5f/785f3ec7eb32f30b90cd0fcf3657d388b5ff4297f2f9716ff66e9b69c05ddd09.git# ll
total 52
drwxr-s--- 7 git root 4096 Aug  3 04:33 ./
drwxr-s--- 4 git root 4096 Jul 22 08:49 ../
-rw-r--r-- 1 git root   23 Jul 22 08:49 HEAD
-rw-r--r-- 1 git root   66 Jul 22 08:49 config
drwxr-sr-x 3 git root 4096 Aug  3 02:04 custom_hooks/
-rw-r--r-- 1 git root   73 Jul 22 08:49 description
drwxr-sr-x 3 git root 4096 Jul 31 04:51 hooks/
drwxr-sr-x 2 git root 4096 Aug  3 04:27 info/
-rw-r--r-- 1 git root  151 Aug  3 04:33 language-stats.cache
drwxr-sr-x 7 git root 4096 Aug  3 04:32 objects/
-rw-r--r-- 1 git root 5150 Aug  3 02:06 packed-refs
drwxr-sr-x 6 git root 4096 Jul 27 02:34 refs/
```

- custom_hooks/配下に`pre-receive.d`ディレクトリを作成
	- `chown git:root pre-receive.d`しておく
```
root@gitlab:/var/opt/gitlab/git-data/repositories/@hashed/78/5f/785f3ec7eb32f30b90cd0fcf3657d388b5ff4297f2f9716ff66e9b69c05ddd09.git/custom_hooks# ll
total 12
drwxr-sr-x 3 git root 4096 Aug  3 02:04 ./
drwxr-s--- 7 git root 4096 Aug  3 04:33 ../
drwxr-sr-x 2 git root 4096 Aug  3 04:41 pre-receive.d/
```

- custom_hooks/pre-receive.d/配下に`pre-receive`ファイルを作成
	- `chown git:root pre-receive`
	- `chmod 755 pre-receive`
	- 中に任意のスクリプト処理を書き込む
```
root@gitlab:/var/opt/gitlab/git-data/repositories/@hashed/78/5f/785f3ec7eb32f30b90cd0fcf3657d388b5ff4297f2f9716ff66e9b69c05ddd09.git/custom_hooks/pre-receive.d# ll
total 12
drwxr-sr-x 2 git root 4096 Aug  3 04:41 ./
drwxr-sr-x 3 git root 4096 Aug  3 02:04 ../
-rwxr-xr-x 1 git root 1993 Aug  3 04:41 pre-receive*
```
- 以上でグローバルなgit hookよりも先にリポジトリローカルのhookが呼ばれる

### branch名をチェックするpre-receive hook

```ruby
#!/opt/gitlab/embedded/bin/ruby

## このファイルについて
## gitlabサーバ側で実行されるgit hook script
## pre-receiveはlocalの開発者がremoteへpushした際にサーバ側で実行され、
## 今回はbranch名が特定の正規表現を満たしているか否かをチェックする

## exitに渡す終了ステータスにより、gitlabへのpushの合否が決まる
## 終了ステータス0 : pushは合格となり、正常に実行される
## 終了ステータス0以外 : pushは不合格となり、拒否される

## 引数から以下を取り出す
## rev_old : pushで変更される前の最新commit
## rev_new : pushで変更された後の最新commit
## ref : branch
rev_old, rev_new, ref = STDIN.read.split(" ")

## 引数の情報を表示
## pre-receiveが標準出力したものはpushを実行したlocalでも表示される
#puts "rev_old : #{rev_old}"
#puts "rev_new : #{rev_new}"
# ref : refs/heads/master
puts "ref : #{ref}"

line = "-------------------------------------------------"

puts line
puts `date`

branch_name = ref.gsub(/refs\/heads\//, "")
## masterに直接pushしたいリポジトリもある
## masterでない場合はprefixとしてfixかfeatureを要求する
## プロジェクトの名前(MY_PROJECT_xx)を必須とする ※xxは任意の2桁の数字
## プロジェクト名に続けて、1-9の1桁の文字列
## あるいは左端の文字が1-9で始まり("001"とか"010"といった0始まりを弾く)、続けて0-9のいずれかが1桁以上続く2桁以上の文字列
## となるような正規表現で弾く
if(branch_name =~ /(master|(fix|feature)\/MY_PROJECT_[1-9][0-9]-([1-9]|[1-9][0-9]{1,}))/)
    puts "ブランチ名の正規表現チェック: OK"
    exit 0
else
    puts "ブランチ名の正規表現チェック: NG"
    puts "ブランチ名{#{branch_name}}は/(master|(fix|feature)\/MY_PROJECT_[1-9][0-9]-([1-9]|[1-9][0-9]{1,}))/ の正規表現に一致しません"
	puts "ブランチ名をfix/MY_PROJECT_10-123 や feature/MY_PROJECT_10-123 のような形式にして下さい(要件はfeature, 不具合修正はfix)"
    exit 1
end
puts line
```

### 指定したパスのリポジトリにpre-receive hookを仕込むrubyスクリプト
- gitlabコンテナの`/var/opt/gitlab/git-data/repositories/@hashed`ディレクトリに移動
- pre-receiveファイルを作成、chmodとchownで権限とか操作
- ↓のrubyスクリプトを作成して`ruby configure_repos_git_hook.rb`で実行するだけ

#### configure_repos_git_hook.rb
```ruby
#!/opt/gitlab/embedded/bin/ruby

## @hashed以下のパスはgitlab管理者メニュー >> プロジェクト >> プロジェクト詳細で
repos = [
"f5/ca/f5ca38f748a1d6eaf7xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.git",
"d5/9e/d59eced1ded07f84c1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.git",
]

repos.each{ |repo|
	Dir.chdir(repo){
		`mkdir -p custom_hooks/pre-receive.d/ && touch custom_hooks/pre-receive.d/pre-receive && chown git:root custom_hooks/ && chown git:root custom_hooks/pre-receive.d && chown git:root custom_hooks/pre-receive.d/pre-receive && chmod 755 custom_hooks/pre-receive.d/pre-receive && ls -la . && ls -la custom_hooks/ && ls -la custom_hooks/pre-receive.d/`
	}
	`cp pre-receive #{repo}/custom_hooks/pre-receive.d/`
	puts `#{repo}/custom_hooks/pre-receive.d/`
}
```
