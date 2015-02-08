# -*- coding: utf-8 -*-
#
# テキストファイル置換ツール
#

require "optparse"
require "timeout"
require_relative 'file_ignore'

module Saferep
  VERSION = "2.0.7".freeze

  class Core
    def self.run(*args)
      new(*args).run
    end

    def self.default_options
      {
        :timeout  => 1.0,
        :ignocase => false,
        :simple   => false,
        :simple_a => false,
        :simple_b => false,
        :word     => false,
        :toutf8   => false,
        :tosjis   => false,
        :guess    => false,
        :all      => false,
      }
    end

    def initialize(src, dest, files, options)
      @options = self.class.default_options.merge(options)

      @src = src
      @dest = dest
      @files = files

      @log = []
      @error_logs = []
      @backup_dir = Pathname("~/tmp").expand_path
      @counts = Hash.new(0)
      @stop = false

      if @options[:simple]
        @options[:simple_a] = true
        @options[:simple_b] = true
      end

      if @options[:simple_a]
        @src = Regexp.quote(@src)
      end

      option = 0
      if @options[:ignocase]
        option |= Regexp::IGNORECASE
      end

      if @options[:word]
        @src = "\\b#{@src}\\b"
      end

      @src_regexp = Regexp.compile(@src, option)
      puts "置換情報:【#{@src_regexp.source}】=>【#{@dest}】(大小文字を区別#{@src_regexp.casefold? ? "しない" : "する"})"

      if @options[:active_support]
        require "active_support/core_ext/string"
      end
    end

    def run
      catch(:exit) do
        @files.each do |filepath|
          Pathname(filepath).find do |fname|
            next if fname.directory?
            @counts[:fetch] += 1
            if @options[:debug]
              puts "find: #{fname.expand_path}"
            end
            skip = false
            begin
              timeout(@options[:timeout]) {
                skip = ignore?(fname)
              }
            rescue Timeout::Error
              puts "【警告】#{fname} の読み込みに時間がかかりすぎです。"
              skip = true
            end
            if skip
              if @options[:debug]
                puts "skip: #{fname}"
              end
              next
            end
            replace(fname)
            if @stop
              throw :exit
            end
          end
        end
      end
      resp_display
    end

    private

    def ignore?(fname)
      return false if @options[:all]
      resp = nil
      resp ||= FileIgnore.ignore?(fname)
      resp ||= fname.basename.to_s.match(/(ChangeLog|\.diff)$/i)
    end

    def replace(fname)
      fname = fname.expand_path
      f = __TARGET_FILE__ = fname
      count = 0
      out = []
      body = fname.read
      guess = nil

      if @options[:toutf8]
        body = body.toutf8
        if @options[:tosjis]
          guess = NKF::SJIS
        else
          if @options[:guess]
            guess = NKF.guess(body)
          else
            guess = NKF::UTF8
          end
        end
      end

      body.lines.each_with_index{|line, index|
        new_line = line.clone
        if @options[:head] && index.next > @options[:head]
        else
          begin
            if new_line.gsub!(@src_regexp) {
                m = match = __MATCH__ = Regexp.last_match
                count += 1
                if @options[:simple_b]
                  @dest
                else
                  eval(%("#{@dest}"), binding)
                end
              }
              puts "#{fname}(#{index.succ}):【#{line.strip}】→【#{new_line.strip}】"
              if @options[:limit] && count >= @options[:limit]
                @stop = true
                break
              end
            end
          rescue ArgumentError => error
            @error_logs << "【読み込み失敗】: #{fname} (#{error})"
            break
          end
        end
        out << new_line
      }
      if count > 0
        @log << "#{fname} (changed #{count})"
      end
      if @options[:exec]
        if count > 0
          bak = backup_file(fname)
          fname.rename(bak)
          if bak.exist?
            out = out.join
            if guess
              out = out.kconv(guess, NKF::UTF8)
            end
            fname.open("w"){|f|f << out}
            fname.chmod(bak.stat.mode)
          end
        end
      end
      @counts[:replace] += count
    end

    def resp_display
      unless @log.empty?
        puts
        puts @log.join("\n")
      end
      unless @error_logs.empty?
        puts
        puts @error_logs.join("\n")
      end
      puts
      puts "結果: #{@log.size} 個のファイルの計 #{@counts[:replace]} 個所を置換しました。(フェッチ数: #{@counts[:fetch]})"
      unless @options[:exec]
        puts
        puts "本当に置換するには -x オプションを付けてください。"
      end
    end

    #
    # バックアップファイル名の取得
    #
    def backup_file(fname)
      unless @backup_dir.exist?
        @backup_dir.mkpath
      end
      ext = ".000"
      loop do
        bak = @backup_dir.join(fname.basename.to_s + ext)
        unless bak.exist?
          break bak
        end
        ext.succ!
      end
    end
  end

  module CLI
    extend self

    def execute(args)
      options = Core.default_options
      oparser = OptionParser.new do |oparser|
        oparser.version = VERSION
        oparser.banner = [
          "テキストファイル置換 #{oparser.ver}\n",
          "使い方: #{oparser.program_name} [オプション] <置換前> <置換後> <ファイル or ディレクトリ>...\n"
        ].join
        oparser.on("オプション:")
        oparser.on("-x", "--exec", "本当に置換する") {|v| options[:exec] = v }
        oparser.on("-w", "--word-regexp", "単語とみなす(#{options[:word]})") {|v| options[:word] = v }
        oparser.on("-s", "-Q", "--simple", "置換前後の文字列を普通のテキストと見なす。-AB 相当。(#{options[:simple]})") {|v| options[:simple] = v }
        oparser.on("-a", "--all", "フィルタせずにすべてのファイルを対象にする(#{options[:all]})") {|v| options[:all] = v }
        oparser.on("-A", "置換前の文字列のみ普通のテキストと見なす(#{options[:simple_a]})") {|v| options[:simple_a] = v }
        oparser.on("-B", "置換後の文字列のみ普通のテキストと見なす(#{options[:simple_b]})") {|v| options[:simple_b] = v }
        oparser.on("-i", "--ignore-case", "大小文字を区別しない(#{options[:ignocase]})") {|v| options[:ignocase] = v }
        oparser.on("-u", "--[no-]utf8", "半角カナを全角カナに統一して置換(#{options[:toutf8]})") {|v| options[:toutf8] = v }
        oparser.on("レアオプション:")
        oparser.on("-g", "--guess", "文字コードをNKF.guessで判断する(#{options[:guess]})") {|v| options[:guess] = v }
        oparser.on("--[no-]sjis", "文字コードをすべてsjisとする(#{options[:tosjis]})") {|v| options[:tosjis] = v }
        oparser.on("--head=N", "先頭のn行のみが対象", Integer) {|v| options[:head] = v }
        oparser.on("--limit=N", "N個置換したら打ち切る", Integer) {|v| options[:limit] = v }
        oparser.on("--activesupport", "active_support/core_ext/string.rb を読み込む") {|v| options[:active_support] = v }
        oparser.on("-d", "--debug", "デバッグ用") {|v| options[:debug] = v }
        oparser.on("--help", "このヘルプを表示する"){puts oparser; abort}
        oparser.on(<<-EOT)
実行例:
  例1. alice → bob
    $ #{oparser.program_name} alice bob
  例2. alice → bob (単語として)
    $ #{oparser.program_name} -w alice bob
  例3. func1 → func(1)
    $ #{oparser.program_name} -w "func(\\d+)" 'func(\#{$1})'
  例5. func(1, 2) → func(2, 1) (引数の入れ替え)
    $ #{oparser.program_name} "func\\((.*?),(.*?)\\)" 'func(\#{$2},\#{$1})'
  例6. func(FooBar) → func(:foo_bar) (引数の定数をアンダースコア表記のシンボルに変換)
    $ #{oparser.program_name} --activesupport "func\\((\\w+)\\)" "func(:\#{\\$1.underscore})"
  例7. 行末スペース削除
    $ #{oparser.program_name} "\\s+$" "\\n"
  例8. シングルクォーテーション → ダブルクォーテーション
    $ #{oparser.program_name} \"'\" \"\\\\\"\"
  例9. 半角カナも含めて全角カナにするには？
    $ #{oparser.program_name} --utf8 カナ かな
  例10. jQuery UIのテーマのCSSの中の url(images/xxx.png) を url(<%= asset_path("themes/(テーマ名)/images/xxx.png") %>) に置換するには？
    $ #{oparser.program_name} "\\burl\\(images/(\\S+?)\\)" 'url(<%= asset_path(\\"themes/\#{f.to_s.scan(/themes\\/(\\S+?)\\//).flatten.first}/images/\#{m[1]}\\") %>)'
  例11. test-unit から rspec への簡易変換
    $ #{oparser.program_name} \"class Test(.*) < Test::Unit::TestCase\" 'describe \#{$1} do'
    $ #{oparser.program_name} \"def test_(\\S+)\" 'it \\\"\#{$1}\\\" do'
    $ #{oparser.program_name} \"assert_equal\\((.*?), (.*?)\\)\" '\#{$2}.should == \#{$1}'
  例12. 1.8形式の require_relative 相当を 1.9 の require_relative に変換
    $ #{oparser.program_name} \"require File.expand_path\\(File.join\\(File.dirname\\(__FILE__\\), \\\"(.*)\\\"\\)\\)\" \"require_relative '\#{\\$1}'\"
  例13. ハッシュを :foo => 1 形式から foo: 1 形式に変換
    $ #{oparser.program_name} \":(\\S+)\\s*=>\\s*\" '\#{$1}: '
  例14. HTMLで閉じタグがないのを直す
    $ #{oparser.program_name} '(<(?:img|meta|link|hr)\\b[^>]+[^/])>' '\#{\$1} />'
EOT
      end

      begin
        args = oparser.parse(args)
      rescue OptionParser::InvalidOption => error
        puts error
        usage(oparser)
      end

      src = args.shift
      dest = args.shift
      if src.nil? || dest.nil?
        usage(oparser)
      end

      if args.empty?
        args << "."
      end

      Saferep::Core.run(src, dest, args, options)
    end

    def usage(oparser)
      puts "使い方: #{oparser.program_name} [オプション] <置換前> <置換後> <ファイル or ディレクトリ>..."
      puts "`#{oparser.program_name} --help' でより詳しい情報を表示します。"
      abort
    end
  end
end

if $0 == __FILE__
  Saferep::CLI.execute(ARGV)
end
