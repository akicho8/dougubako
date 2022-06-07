# -*- coding: utf-8 -*-
# テキストファイル置換ツール

require "optparse"
require "timeout"
require_relative 'file_ignore'

module Saferep
  VERSION = "2.0.8"

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
        :tate     => false,
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
            if fname.directory?
              if fname.basename.to_s.start_with?(".") || fname.basename.to_s.match?(/\b(?:log)\b/)
                Find.prune
              end
            end
            @counts[:fetch] += 1
            if @options[:debug]
              puts "find: #{fname.expand_path}"
            end
            skip = false
            begin
              Timeout.timeout(@options[:timeout]) do
                skip = ignore?(fname)
              end
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
      response_display
    end

    private

    def ignore?(fname)
      return false if @options[:all]
      resp = nil
      resp ||= FileIgnore.ignore?(fname)
      resp ||= fname.basename.to_s.match(/(ChangeLog|\.diff)\z/i)
      unless resp
        # if fname.to_s.match(/(\.css)\z/i)
        #   fname.read.size >=
        # end
      end
      resp
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
              if @options[:tate]
                puts "#{fname}(#{index.succ}):"
                puts "  【#{line.strip}】"
                puts "  【#{new_line.strip}】"
              else
                puts "#{fname}(#{index.succ}):【#{line.strip}】→【#{new_line.strip}】"
              end
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
            fname.write(out)
            fname.chmod(bak.stat.mode)
          end
        end
      end
      @counts[:replace] += count
    end

    def response_display
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
      oparser = OptionParser.new do |opts|
        opts.version = VERSION
        opts.banner = [
          "テキストファイル置換 #{opts.ver}\n",
          "使い方: #{opts.program_name} [オプション] <置換前> <置換後> <ファイル or ディレクトリ>...\n"
        ].join
        opts.on("オプション:")
        opts.on("-x", "--exec", "本当に置換する") {|v| options[:exec] = v }
        opts.on("-w", "--word-regexp", "単語とみなす(#{options[:word]})") {|v| options[:word] = v }
        opts.on("-s", "-Q", "--simple", "置換前後の文字列を普通のテキストと見なす。-AB 相当。(#{options[:simple]})") {|v| options[:simple] = v }
        opts.on("-a", "--all", "フィルタせずにすべてのファイルを対象にする(#{options[:all]})") {|v| options[:all] = v }
        opts.on("-A", "置換前の文字列のみ普通のテキストと見なす(#{options[:simple_a]})") {|v| options[:simple_a] = v }
        opts.on("-B", "置換後の文字列のみ普通のテキストと見なす(#{options[:simple_b]})") {|v| options[:simple_b] = v }
        opts.on("-i", "--ignore-case", "大小文字を区別しない(#{options[:ignocase]})") {|v| options[:ignocase] = v }
        opts.on("-l", "置換情報を縦に表示する(#{options[:tate]})") {|v| options[:tate] = v }
        opts.on("-u", "--[no-]utf8", "半角カナを全角カナに統一して置換(#{options[:toutf8]})") {|v| options[:toutf8] = v }
        opts.on("レアオプション:")
        opts.on("-g", "--guess", "文字コードをNKF.guessで判断する(#{options[:guess]})") {|v| options[:guess] = v }
        opts.on("--[no-]sjis", "文字コードをすべてsjisとする(#{options[:tosjis]})") {|v| options[:tosjis] = v }
        opts.on("--head=N", "先頭のn行のみが対象", Integer) {|v| options[:head] = v }
        opts.on("--limit=N", "N個置換したら打ち切る", Integer) {|v| options[:limit] = v }
        opts.on("--activesupport", "active_support/core_ext/string.rb を読み込む") {|v| options[:active_support] = v }
        opts.on("-d", "--debug", "デバッグ用") {|v| options[:debug] = v }
        opts.on("--help", "このヘルプを表示する"){puts opts; abort}
        opts.on(<<-EOT)
実行例:
  例1. alice → bob
    $ #{opts.program_name} alice bob
  例2. alice → bob (単語として)
    $ #{opts.program_name} -w alice bob
  例3. func1 → func(1)
    $ #{opts.program_name} -w "func(\\d+)" 'func(\#{$1})'
  例5. func(1, 2) → func(2, 1) (引数の入れ替え)
    $ #{opts.program_name} "func\\((.*?),(.*?)\\)" 'func(\#{$2},\#{$1})'
  例6. func(FooBar) → func(:foo_bar) (引数の定数をアンダースコア表記のシンボルに変換)
    $ #{opts.program_name} --activesupport "func\\((\\w+)\\)" "func(:\#{\\$1.underscore})"
  例7. 行末スペース削除
    $ #{opts.program_name} "\\s+$" "\\n"
  例8. シングルクォーテーション → ダブルクォーテーション
    $ #{opts.program_name} \"'\" \"\\\\\"\"
  例9. 半角カナも含めて全角カナにするには？
    $ #{opts.program_name} --utf8 カナ かな
  例10. jQuery UIのテーマのCSSの中の url(images/xxx.png) を url(<%= asset_path("themes/(テーマ名)/images/xxx.png") %>) に置換するには？
    $ #{opts.program_name} "\\burl\\(images/(\\S+?)\\)" 'url(<%= asset_path(\\"themes/\#{f.to_s.scan(/themes\\/(\\S+?)\\//).flatten.first}/images/\#{m[1]}\\") %>)'
  例11. test-unit から rspec への簡易変換
    $ #{opts.program_name} \"class Test(.*) < Test::Unit::TestCase\" 'describe \#{$1} do'
    $ #{opts.program_name} \"def test_(\\S+)\" 'it \\\"\#{$1}\\\" do'
    $ #{opts.program_name} \"assert_equal\\((.*?), (.*?)\\)\" '\#{$2}.should == \#{$1}'
  例12. 1.8形式の require_relative 相当を 1.9 の require_relative に変換
    $ #{opts.program_name} \"require File.expand_path\\(File.join\\(File.dirname\\(__FILE__\\), \\\"(.*)\\\"\\)\\)\" \"require_relative '\#{\\$1}'\"
  例13. ハッシュを :foo => 1 形式から foo: 1 形式に変換
    $ #{opts.program_name} \":(\\S+)\\s*=>\\s*\" '\#{$1}: '
  例14. HTMLで閉じタグがないのを直す
    $ #{opts.program_name} '(<(?:img|meta|link|hr)\\b[^>]+[^/])>' '\#{\$1} />'
  例15. ActiveRecord::Base のサブクラスのモデルの先頭に指定モジュールを include する
    $ #{opts.program_name} \"^(class \\S+ < ActiveRecord::Base.*)\" '\#{\$1}\\n  include M'
  例16. Rubyのマジックコメント '# -*- coding: utf-8 -*-' の行を改行を含めて消す
    $ #{opts.program_name} '# -\\*- coding: utf-8 -\\*-\\n' ''
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

      Core.run(src, dest, args, options)
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
