コマンドライン用便利ツール集
============================

ファイル整形ツール
------------------

    $ safefile --help
    ファイル整形ツール safefile 1.0.0
    使い方: safefile [オプション] ディレクトリ or ファイル...
    オプション:
        -x, --exec                       本当に置換する
        -r, --recursive                  サブディレクトリも対象にする(デフォルト:false)
        -s, --[no-]rstrip                rstripする(初期値:true)
        -b, --[no-]delete-blank-lines    2行以上の空行を1行にする(初期値:true)
        -z, --[no-]hankaku               「ａ-ｚＡ-Ｚ０-９（）／＊」を半角にする(初期値:true)
        -Z, --[no-]hankaku-space         全角スペースを半角スペースにする(初期値:true)
        -d, --[no-]diff                  diffの表示(初期値:false)
        -w, --windows                    SHIFT-JISで改行も CR + LF にする(初期値:false)
        -f, --force                      強制置換する
    使用例:
        1. カレントディレクトリのすべてのファイルを整形する
          $ safefile .
        2. サブディレクトリを含め、diffで整形結果を確認する
          $ safefile -rd .
        3. カレントの *.bat のファイルをWindows用に置換する
          $ safefile -w *.bat

## サブディレクトリを含めて置換してdiffを表示する例

    $ safefile -rd .
    .U a/b/file2.txt (1 diffs)
    -------------------------------------------------------------------------------- [1/1]
    a/b/file2.txt:1: - キン肉マン　マッスルタッグマッチ
    a/b/file2.txt:1: + キン肉マン マッスルタッグマッチ
    --------------------------------------------------------------------------------
    U a/file1.txt (2 diffs)
    -------------------------------------------------------------------------------- [1/2]
    a/file1.txt:1: - バトルシティー 
    a/file1.txt:1: + バトルシティー
    -------------------------------------------------------------------------------- [2/2]
    a/file1.txt:2: - ルート１６ターボ
    a/file1.txt:2: + ルート16ターボ
    --------------------------------------------------------------------------------
    2 個のファイルの中から 2 個を置換しました。総diffは 3 行です。
    本当に置換するには -x オプションを付けてください。

ファイルを連番にリネームするスクリプト
--------------------------------------

    $ n --help
    ファイルを連番にリネームするスクリプト n 1.1.0
    使い方: n [オプション] 対象ディレクトリ...
    オプション:
        -x, --exec                       実際に実行する(デフォルト:false)
        -r, --recursive                  サブディレクトリも対象にする(デフォルト:false)
        -a, --all                        すべてのファイルを対象にする？(デフォルト:false)
        -c, --reject-basename            ベースネームを捨てる？(デフォルト:false)
            --base=INTEGER               インデックスの最初(デフォルト:100)
            --step=INTEGER               インデックスのステップ(デフォルト:10)
            --zero=INTEGER               先頭に入れる0の数(デフォルト:1)
        -n, --number-only                ゼロパディングせず番号のみにする(デフォルト:false)
        -v, --verbose                    詳細表示(デフォルト:false)
        -h, --help                       このヘルプを表示する
    
    サンプル:
        例1. カレントディレクトリの《番号_名前.拡張子》形式のファイルを同じ形式でリナンバーする
            % n .
        例2. 指定ディレクトリ以下のすべてのファイルを《番号.拡張子》形式にリネームする
            % n -rac ~/Pictures/Archives

## カレントディレクトリのファイルをリナンバーするには？(BASICのRENUM相当)

    ~/.emacs.d $ n .
    [DIR] /Users/alice/.emacs.d (101 files)
      U [  8/101] 00161_rubikichi.el => 00170_rubikichi.el
      U [  9/101] 00165_etc.el => 00180_etc.el
      U [ 10/101] 00170_find_file_direct.el => 00190_find_file_direct.el
    (snip)
    差分:94 ディレクトリ数:94 ファイル数:101 個を処理しました。
    本当に実行するには -x オプションを付けてください。

    ※上記の結果から問題がなければ -x オプションをつけて本当に実行する

    ~/.emacs.d $ n . -x
    [DIR] /Users/alice/.emacs.d (101 files)
      U [  8/101] 00161_rubikichi.el => 00170_rubikichi.el
      U [  9/101] 00165_etc.el => 00180_etc.el
      U [ 10/101] 00170_find_file_direct.el => 00190_find_file_direct.el
    (snip)
    差分:94 ディレクトリ数:94 ファイル数:101 個を処理しました。

## 階層ディレクトリの中にある画像をすべて連番にして整理するには？

    $ n --recursive --all --reject-basename ~/Pictures
    [DIR] /Users/alice/Pictures/Archives/深海魚 (20 files)
      U [ 1/20] a.jpg => 0100.jpg
      U [ 2/20] b.jpg => 0110.jpg
    [DIR] /Users/alice/Pictures/Archives/初音ミク (30 files)
      U [ 1/30] c.jpg => 0100.jpg
      U [ 2/30] d.jpg => 0110.jpg
    差分:4 ディレクトリ数:4 ファイル数:4 個を処理しました。
    本当に実行するには -x オプションを付けてください。

## 階層ディレクトリの中にある画像をすべて1からはじまる数値のみの連番にするには？

    $ n --recursive --all --number-only --base=1 --step=1 ~/Pictures
    [DIR] /Users/alice/src/project/images/a (20 files)
      U [ 1/20] 2.jpg => 1.jpg
      U [ 2/20] 4.jpg => 2.jpg
    [DIR] /Users/alice/src/project/images/b (30 files)
      U [ 1/30] 3.jpg => 1.jpg
      U [ 2/30] 5.jpg => 2.jpg
    差分:4 ディレクトリ数:4 ファイル数:4 個を処理しました。
    本当に実行するには -x オプションを付けてください。
