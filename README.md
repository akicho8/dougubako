コマンドライン用便利ツール集
============================

ファイルを連番にリネームするスクリプト
--------------------------------------

## オプション一覧

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
