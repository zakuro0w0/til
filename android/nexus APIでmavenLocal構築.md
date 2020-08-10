# nexus APIでmavenLocal構築

## やりたいこと
- nexusコンテナで立てたmavenリポジトリ同等のファイルツリーをローカルに再現したい
  - 社内プロキシ環境関係でリモートの社内mavenリポジトリから取り込めない場合の対策として必要になった

## 使うもの
- ruby
- nexus API
  - nexusコンテナが公開するRestAPIにより、色々条件を指定してバイナリをダウンロードできる
  - ローカルの`~/.m2/repository/`がmavenLocalのデフォルト参照先なので、パッケージのディレクトリ構成を再現したファイルツリーがあれば出来るはず

## pull_maven_local.rb


```ruby
require 'net/http'
require 'json'
require 'open-uri'
require "fileutils"

## このファイル(pull_maven_local.rb)について
## 開発LANが来るまでの暫定対策として、開発者のAndroidStudioから参照するmavenリポジトリは
## リモート(nexusコンテナ)の中身をコピーしたmavenローカルリポジトリとする必要がある.
## このファイルはリモートのnexusコンテナに登録されたjarやaarといったライブラリを、
## mavenリポジトリとして参照できるディレクトリ構成でダウンロードするためのスクリプトを提供する.

## 使い方
## 1. mavenLocalリポジトリとして参照させたい任意のディレクトリに移動する
##      ※gradleがデフォルトでmavenLocalとして認識するのは"~/.m2/repository/"である
## 2. `ruby pull_maven_local.rb`コマンドでこのファイルを実行


## nexusコンテナのmavenリポジトリで管理されるandroid向けバイナリを表現したクラス
class MavenBinary
    attr_reader :downloadUrl, :version, :artifactId, :groupId, :extension

    ## downloadUrl="http://mymaven.com:8081/repository/maven-releases/com/example/nebulapublish/mylibrary/3.0.0/mylibrary-3.0.0.aar"
    ## path="com/example/nebulapublish/mylibrary/3.0.0/mylibrary-3.0.0.aar"
    def initialize(downloadUrl, path)
        @downloadUrl = downloadUrl
        ## mylibrary
        @artifactId = extractArtifactId(downloadUrl)
        ## 3.0.0
        @version = extractVersion(downloadUrl)
        ## com/example/nebulapublish
        ## pathから正規表現でアーティファクトID以降を削除したものをgroupIdとして取得
        @groupId = path.gsub(/\/#{@artifactId}.*$/, "")
        ## .aar
        @extension = File.extname(path)
    end

    ## pathからアーティファクトIDを抽出して返す
    def extractArtifactId(path)
        ## filename="mylibrary-3.0.0.aar"
        filename = File.basename(path)
        ## return="mylibrary"
        return filename.split('-')[0]
    end

    ## pathからバージョンを抽出して返す
    def extractVersion(path)
        ## filename="mylibrary-3.0.0"
        filename = File.basename(path, ".*")
        ## return="3.0.0"
        return filename.split('-')[1]
    end

    ## デバッグ用
    def print()
        puts "--------------------------------"
        puts "downloadUrl=#{@downloadUrl}"
        puts "groupId=#{@groupId}"
        puts "artifactId=#{@artifactId}"
        puts "extension=#{@extension}"
        puts "version=#{@version}"
    end
end

## uriのファイルをfilepathとしてダウンロードする
def download(uri, filepath)
    URI.open(uri) do |file|
        open(filepath, "w+b") do |out|
            out.write(file.read)
        end
    end
end

## extensionで指定した拡張子のファイルをmavenから集め、saveDirectoryに保存する
def collectLatestBinary(extension)
    ## nexus APIのURI "service/rest/v1/search/assets" : 指定した条件に一致するバイナリを検索する
    ## search/assets/downloadもあったが、取得できる情報が不足しており不採用(アーティファクトIDやバージョンをversion.ymlに保存したい)
    ## sort=version : バージョンの降順(新しい順)に結果を並び変える
    ## repository=maven-releases : nexusのmaven-snapshot(開発中バージョン)ではなく、maven-releases(正式リリースバージョン)にuploadされたバイナリのみを検索対象とする
    ## maven.extension : ファイル拡張子を指定する
    uri = "http://mymaven.com:8081/service/rest/v1/search/assets?sort=version&repository=maven-releases&maven.extension=#{extension}"

    ## レスポンスをjsonとして取り出す
    json = JSON.parse(Net::HTTP.get(URI.parse(uri)))

    binList = []
    json["items"].each{ |item|
        ## レスポンスからMavenBinaryインスタンスを構築
        binList.push(MavenBinary.new(item["downloadUrl"], item["path"]))
    }

    binList.each{ |bin|
        bin.print()

        directoryPath = "#{bin.groupId}/#{bin.artifactId}/#{bin.version}"
        FileUtils.mkdir_p(directoryPath)
        ## バイナリを指定の位置にダウンロードする
        download(bin.downloadUrl, "#{directoryPath}/#{bin.artifactId}#{bin.extension}")
    }
end

collectLatestBinary("aar")
collectLatestBinary("jar")
collectLatestBinary("pom")
```