
# 起動方法
# $julia zero_kata.jl

# 構造体を宣言できる
struct Pos
    # メンバの宣言
    # ::Typeで型を明示することもできる
    x::Int
    y::Int
end

# 列挙型の宣言
# 列挙要素は半角スペースで区切って羅列する
# 異なる列挙型の間での名前重複は出来ないっぽい、名前空間(module)が異なれば多分OK
@enum CellStatus none o x
@enum Player you opponent

# 変更可能な構造体
# stateの値が変更されるため、mutableが必要
# 通常は暗黙的にimmutableで宣言されるので、明示する必要がある
mutable struct Cell
    state::CellStatus
    pos::Pos
end

# 関数の宣言
# 引数の型も明示できる
function printCell(cell::Cell)
    # switchとかwhenが無い？どう書けば良いのか
    if cell.state == none
        print(".")
    elseif cell.state == o
        print("o")
    else cell.state == x
        print("x")
    # if文はendで閉める
    end
# 関数もendで閉める
end

function printLine(lineNum, cells)
    # 文字列中で変数を参照するには$を付ける
    # $(expression) のように()で囲めば式の記述も可能
    print("$lineNum|")
    # iterableオブジェクトに対するforeachは↓のように書く
    # 第1引数には要素に対して実行する関数
    # 第2引数には配列やtuple等のiterableオブジェクト
    foreach(printCell, cells)
    println("|")
end

function initField()
    # 変数の宣言はいきなり名前から書けばOK(field)
    # 構造体のインスタンス作成はメンバ定義順に引数を与える(Pos(1, 1))
    # fill(object, (x, y))はx行y列の2次元配列を作成し、全ての要素をobjectで初期化する
    field = fill(Cell(none, Pos(1, 1)), (3, 3))
    # for文の繰り返しは↓のように書ける
    # 1:3 の記述は範囲を示しており、1から始まり、1刻みで3までの範囲、つまり[1,2,3]の配列を表現する
    # step(刻み値)は省略可能で、デフォルトでは1刻みになる、明示する場合は1:1:3となる
    # 1:0.5:3 にした場合は1から3までを0.5刻みになるので、[1, 1.5, 2, 2.5, 3]の配列となる
    # 変動する変数は複数定義することが可能で、以下のようにx,yを書いた場合は(x, y)全ての組み合わせが実行される
    for x = 1:3, y = 1:3
        # 2次元配列へのアクセスは[x, y]で可能
        field[x, y] = Cell(none, Pos(x, y))
    end
    # juliaの関数は最後の式の評価が戻り値となるので、↓のreturnは書かなくても良い
    return field
end

# 配列の型は Array{要素の型、次元の数} で表現される
# ↓のfieldはCell構造体を要素とする2次元配列となる
function printField(field::Array{Cell, 2})
    println(" |123|")
    println("-+---+")
    for i = 1:3
        # 2次元配列のアクセスで[i, :]とした場合、i行目の要素全てを持つ1次元配列が入手できる
        printLine(i, field[i, :])
    end
    println("-+---+")
end

function getPlayerSign(player)
    if player == you
        return o
    else
        return x
    end
end

function requirePosition(currentPlayer)
    println("it's [$(getPlayerSign(currentPlayer))] turn!!")
    print("please enter next Pos(x, y). example 1 2 : ")
    # 標準入力からのデータ取得にはreadline()を使う、改行がデータに含まれないためにchomp()も併用する
    # "x y" のような形式の入力はsplit()で半角スペースをseparatorとした配列化を行う
    # parse.(型, 配列) はparse()関数を配列の要素全てに適用した結果を返してくれる
    # 関数名の後に"."を付けることがbroadcastと呼ばれ、map()関数のように使える
    # ここではsplitで入手した文字列の配列要素を全てInt型にキャストしている
    # また、(x, y) = のように無名のtupleで受け取ることも可能
    (x, y) = parse.(Int, split(chomp(readline())))
    println("(x, y)=($x, $y)")
    Pos(x, y)
end

function getNextPlayer(currentPlayer)
    if currentPlayer == you
        opponent
    else
        you
    end
end

function markCell(player, pos, field)
    field[pos.x, pos.y].state = getPlayerSign(player)
end

function isAllSameMark(cells)
    isAllSameMark = false
    # inの後ろに列挙した配列各々について繰り返す
    for state in [o, x]
        # filter()はiterableオブジェクトから第1引数で指定した式の条件を満たす要素だけ取り出す関数
        # length()は配列の長さを取る
        isAllSameMark |= length(filter(cell->cell.state==state, cells)) == length(cells)
    end
    isAllSameMark
end

function isGameOver(field)
    isGameOver = false
    for x = 1:3
        # 行だけを抽出して判定
        isGameOver |= isAllSameMark(field[x, :])
        # 列だけを抽出して判定
        isGameOver |= isAllSameMark(field[:, x])
    end
    # 対角線上の要素だけを抽出して判定
    isGameOver = isAllSameMark(field[CartesianIndex.(1:3, 1:3)])
    # 逆側の対角要素だけを抽出して判定
    isGameOver = isAllSameMark(field[CartesianIndex.(1:3, 3:-1:1)])
    isGameOver
end

field = initField()
currentPlayer = opponent

while !isGameOver(field)
    printField(field)
    # whileやif文はスコープを作る
    # スコープ外の変数を変更する場合はglobal宣言が必要らしい
    global currentPlayer = getNextPlayer(currentPlayer)
    pos = requirePosition(currentPlayer)
    markCell(currentPlayer, pos, field)
end

printField(field)
println("congraturation!! $(currentPlayer) is won!!")

