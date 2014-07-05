コマンドライン用便利ツール集
============================

テキストファイル置換
--------------------

    $ r --help
    テキストファイル置換 r 2.0.5
    使い方: r [オプション] <置換前> <置換後> <ファイル or ディレクトリ>...
    オプション:
        -x, --exec                       本当に置換する
        -w, --word-regexp                単語とみなす(false)
        -s, --simple                     置換前の文字列を普通のテキストと見なす(false)
        -A                               置換前の文字列のみ普通のテキストと見なす(false)
        -B                               置換後の文字列のみ普通のテキストと見なす(false)
        -i, --ignore-case                大小文字を区別しない(false)
        -u, --[no-]utf8                  半角カナを全角カナに統一して置換(false)
    レアオプション:
        -g, --guess                      文字コードをNKF.guessで判断する(false)
            --[no-]sjis                  文字コードをすべてsjisとする(false)
            --head=N                     先頭のn行のみが対象
            --limit=N                    N個置換したら打ち切る
        -d, --debug                      デバッグ用
            --help                       このヘルプを表示する
    実行例:
      例1. alice → bob
        $ r alice bob
      例2. alice → bob (単語として)
        $ r -w alice bob
      例3. func1 → func(1)
        $ r -w "func(\d+)" 'func(#{$1})'
      例5. func(1, 2) → func(2, 1) (引数の入れ替え)
        $ r "func\((.*?),(.*?)\)" 'func(#{$2},#{$1})'
      例6. func(FooBar) → func(:foo_bar) (引数の定数をアンダースコア表記のシンボルに変換)
        $ r --activesupport "func\((\w+)\)" "func(:#{\$1.underscore})"
      例7. 行末スペース削除
        $ r "\s+$" "\n"
      例8. シングルクォーテーション → ダブルクォーテーション
        $ r "'" "\\""
      例9. 半角カナも含めて全角カナにするには？
        $ r --utf8 カナ かな
      例10. jQuery UIのテーマのCSSの中の url(images/xxx.png) を url(<%= asset_path("themes/(テーマ名)/images/xxx.png") %>) に置換するには？
        $ r "\burl\(images/(\S+?)\)" 'url(<%= asset_path(\"themes/#{f.to_s.scan(/themes\/(\S+?)\//).flatten.first}/images/#{m[1]}\") %>)'
      例11. test-unit から rspec への簡易変換
        $ r "class Test(.*) < Test::Unit::TestCase" 'describe #{$1} do'
        $ r "def test_(\S+)" 'it \"#{$1}\" do'
        $ r "assert_equal\((.*?), (.*?)\)" '#{$2}.should == #{$1}'
      例12. 1.8形式の require_relative 相当を 1.9 の require_relative に変換
        $ r "require File.expand_path\(File.join\(File.dirname\(__FILE__\), \"(.*)\"\)\)" "require_relative '#{\$1}'"

文字列検索
----------

    $ g --help
    文字列検索 g 2.0.3
    使い方: g [オプション] <検索文字列> <ファイル or ディレクトリ>...
    オプション
        -i, --ignore-case                大小文字を区別しない(false)
        -w, --word-regexp                単語とみなす(false)
        -s                               検索文字列をエスケープ(false)
        -a                               コメント行も含める(false)
        -u, --[no-]utf8                  半角カナを全角カナに統一(false)
        -d, --debug                      デバッグモード
            --help                       このヘルプを表示する


ファイル整形
------------

    $ safefile --help
    ファイル整形 safefile 1.0.0
    使い方: safefile [オプション] ディレクトリ or ファイル...
    オプション:
        -x, --exec                       本当に置換する
        -r, --recursive                  サブディレクトリも対象にする(デフォルト:false)
        -s, --[no-]rstrip                rstripする(true)
        -b, --[no-]delete-blank-lines    2行以上の空行を1行にする(true)
        -z, --[no-]hankaku               「ａ-ｚＡ-Ｚ０-９（）／＊」を半角にする(true)
        -Z, --[no-]hankaku-space         全角スペースを半角スペースにする(true)
        -d, --[no-]diff                  diffの表示(false)
        -u, --[no-]uniq                  同じ行が続く場合は一行にする(false)
        -w, --windows                    SHIFT-JISで改行も CR + LF にする(false)
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

## 連続する同じ内容の行を削除する例

    $ cat test.txt
    a
    a
    b
    a
    a

    $ safefile -ux test.txt
    U test.txt (2 diffs)
    1 個のファイルの中から 1 個を置換しました。総diffは 2 行です。
    
    $ cat test.txt
    a
    b
    a

ファイル名リナンバー
--------------------------------------

    $ renum --help
    ファイル名リナンバー renum 1.1.0
    使い方: renum [オプション] 対象ディレクトリ...
    オプション:
        -x, --exec                       実際に実行する(デフォルト:false)
        -r, --recursive                  サブディレクトリも対象にする(デフォルト:false)
        -a, --all                        すべてのファイルを対象にする？(デフォルト:false)
        -c, --reject-basename            ベースネームを捨てる？(デフォルト:false)
        -b, --base=INTEGER               インデックスの最初(デフォルト:100)
        -s, --step=INTEGER               インデックスのステップ(デフォルト:10)
        -z, --zero=INTEGER               先頭に入れる0の数(デフォルト:1)
        -n, --number-only                ゼロパディングせず番号のみにする(デフォルト:false)
        -v, --verbose                    詳細表示(デフォルト:false)
        -h, --help                       このヘルプを表示する
    サンプル:
        例1. カレントディレクトリの《番号_名前.拡張子》形式のファイルを同じ形式でリナンバーする
            % renum .
        例2. 指定ディレクトリ以下のすべてのファイルを《番号.拡張子》形式にリネームする
            % renum -rac ~/Pictures/Archives

## BASIC の RENUM コマンドのようにファイル名をリナンバーする例

    ~/.emacs.d $ renum .
    [DIR] /Users/alice/.emacs.d (101 files)
      U [  8/101] 00161_rubikichi.el => 00170_rubikichi.el
      U [  9/101] 00165_etc.el => 00180_etc.el
      U [ 10/101] 00170_find_file_direct.el => 00190_find_file_direct.el
    (snip)
    差分:94 ディレクトリ数:94 ファイル数:101 個を処理しました。
    本当に実行するには -x オプションを付けてください。

    ※上記の結果から問題がなければ -x オプションをつけて本当に実行する

    ~/.emacs.d $ renum . -x
    [DIR] /Users/alice/.emacs.d (101 files)
      U [  8/101] 00161_rubikichi.el => 00170_rubikichi.el
      U [  9/101] 00165_etc.el => 00180_etc.el
      U [ 10/101] 00170_find_file_direct.el => 00190_find_file_direct.el
    (snip)
    差分:94 ディレクトリ数:94 ファイル数:101 個を処理しました。

## 階層ディレクトリをすべて対象にする

    ※ --all ですべてのファイルを対象にして --reject-basename で元のファイル名をカットする

    $ renum --recursive --all --reject-basename ~/Pictures
    [DIR] /Users/alice/Pictures/Archives/深海魚 (20 files)
      U [ 1/20] a.jpg => 0100.jpg
      U [ 2/20] b.jpg => 0110.jpg
    [DIR] /Users/alice/Pictures/Archives/初音ミク (30 files)
      U [ 1/30] c.jpg => 0100.jpg
      U [ 2/30] d.jpg => 0110.jpg
    差分:4 ディレクトリ数:4 ファイル数:4 個を処理しました。
    本当に実行するには -x オプションを付けてください。

## 1からはじまる数値のみの連番にするには？

    --base から --step ごとにインクリメント
    --number-only で 0 のプレフィクスをつけない

    $ renum --recursive --all --number-only --base=1 --step=1 images
    [DIR] images/a (20 files)
      U [ 1/20] a.jpg => 1.jpg
      U [ 2/20] c.jpg => 2.jpg
    [DIR] images/b (30 files)
      U [ 1/30] 3.jpg => 1.jpg
      U [ 2/30] 5.jpg => 2.jpg
    差分:4 ディレクトリ数:4 ファイル数:4 個を処理しました。
    本当に実行するには -x オプションを付けてください。

## cronに仕掛けておくことで画像ディレクトリを自動整理

    0 6 * * * renum -racx ~/Pictures/Archives | nkf -j

    [DIR] /Users/alice/Pictures/Archives/壁紙 (20 files)
    U [ 1/20] 010b9417.jpg => 0100.jpg
    U [ 2/20] 02827811.jpg => 0110.jpg
    U [ 3/20] 0e21bff0.jpg => 0120.jpg
    U [ 4/20] 102264ad.jpg => 0130.jpg
    U [ 5/20] 116fbe08.jpg => 0140.jpg
    U [ 6/20] 12636f63.jpg => 0150.jpg
    U [ 7/20] 143c9d2d.jpg => 0160.jpg
    U [ 8/20] 165c586f.jpg => 0170.jpg
    U [ 9/20] 1758ec7f.jpg => 0180.jpg
    U [10/20] 19a9b86e.jpg => 0190.jpg
    U [11/20] 24942625.jpg => 0200.jpg
    U [12/20] 27061b37.jpg => 0210.jpg
    U [13/20] 2a24bc45.jpg => 0220.jpg
    U [14/20] 2ac04638.jpg => 0230.jpg
    U [15/20] 30111072.jpg => 0240.jpg
    U [16/20] 31bc63a8.jpg => 0250.jpg
    U [17/20] 3bca8b86.jpg => 0260.jpg
    U [18/20] 3e9b6c4e.jpg => 0270.jpg
    U [19/20] 3ebf5a47.jpg => 0280.jpg
    U [20/20] 3f746de3.jpg => 0290.jpg
