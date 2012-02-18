# -*- coding: utf-8 -*-
#
# テキストファイル置換ツール
#

require "optparse"
require "timeout"
require_relative 'file_filter'

module Saferep
  VERSION = "2.0.4".freeze

  class Core
    def self.run(*args)
      new(*args).run
    end

    def self.default_options
      {
        :timeout  => 1.0,
        :ignocase => false,
        :simple   => false,
        :word     => false,
        :toutf8   => false,
      }
    end

    def initialize(src, dst, files, options)
      @options = self.class.default_options.merge(options)

      @src = src
      @dst = dst
      @files = files

      @log = []
      @error_logs = []
      @backup_dir = Pathname("~/tmp").expand_path
      @counts = Hash.new(0)
      @stop = false

      if @options[:simple]
        @src = Regexp.quote(@src)
      end

      option = 0
      if @options[:ignocase]
        option |= Regexp::IGNORECASE
      end

      if @options[:word]
        @src = "\\b#{@src}\\b"
      end

      @srcreg = Regexp.compile(@src, option)
      puts "置換情報:【#{@srcreg.source}】=>【#{@dst}】(大小文字を区別#{@srcreg.casefold? ? "しない" : "する"})"
    end

    def run
      catch(:exit) do
        @files.each do |filepath|
          Pathname(filepath).find do |fname|
            @counts[:fetch] += 1
            if @options[:debug]
              puts "find: #{fname.expand_path}"
            end
            skip = false
            begin
              timeout(@options[:timeout]) {
                skip = ignore_file?(fname)
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

    def ignore_file?(fname)
      resp = nil
      resp ||= FileFilter.ignore_file?(fname)
      resp ||= fname.basename.to_s.match(/(ChangeLog|\.diff)$/i)
    end

    def replace(fname)
      fname = fname.expand_path
      f = __TARGET_FILE__ = fname
      count = 0
      out = []
      content = fname.read
      guess = nil

      if @options[:toutf8]
        content = content.toutf8
        if @options[:sjis]
          guess = NKF::SJIS
        else
          if @options[:guess]
            guess = NKF.guess(content)
          else
            guess = NKF::UTF8
          end
        end
      end

      content.lines.each_with_index{|line, index|
        new_line = line.clone
        do_gsub = true
        if @options[:head] && index.next > @options[:head]
          do_gsub = false
        end
        if do_gsub
          begin
            if new_line.gsub!(@srcreg){
                m = match = __MATCH__ = Regexp.last_match
                count += 1
                if @options[:simple]
                  @dst
                else
                  eval(%("#{@dst}"), binding)
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
              out = out.join.kconv(guess, NKF::UTF8)
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
          "テキストファイル置換スクリプト #{oparser.ver}\n",
          "使い方: #{oparser.program_name} [オプション] <置換前> <置換後> <ファイル or ディレクトリ>...\n"
        ].join
        oparser.on("オプション:")
        oparser.on("-x", "--exec", "本当に置換する"){|v|options[:exec] = v}
        oparser.on("-w", "--word-regexp", "単語とみなす(初期値:#{options[:word]})"){|v|options[:word] = v}
        oparser.on("-s", "--simple", "置換前の文字列を普通のテキストと見なす(初期値:#{options[:simple]})"){|v|options[:simple] = v}
        oparser.on("-i", "--ignore-case", "大小文字を区別しない(初期値:#{options[:ignocase]})"){|v|options[:ignocase] = v}
        oparser.on("-u", "--[no-]utf8", "半角カナを全角カナに統一して置換(初期値:#{options[:toutf8]})"){|v|options[:toutf8] = v}
        oparser.on("レアオプション:")
        oparser.on("-g", "--guess", "文字コードをNKF.guessで判断する(初期値:#{options[:guess]})"){|v|options[:guess] = v}
        oparser.on("--sjis", "文字コードをすべてsjisとする(初期値:#{options[:sjis]})"){|v|options[:sjis] = v}
        oparser.on("--head=N", "先頭のn行のみが対象", Integer){|v|options[:head] = v}
        oparser.on("--limit=N", "N個置換したら打ち切る", Integer){|v|options[:limit] = v}
        oparser.on("-d", "--debug", "デバッグ用"){|v|options[:debug] = v}
        oparser.on("--help", "このヘルプを表示する"){puts oparser; abort}
        oparser.on(<<-EOT)
実行例:
  例1. foo という文字列を bar に置換するには？ (カレント以下のテキストファイルが対象)
    $ #{oparser.program_name} foo bar
  例2. foo という単語を bar に置換するには？
    $ #{oparser.program_name} -w foo bar
  例3. foo123 のように後ろに不定の数字がついた単語を bar(123) に置換するには？
    $ #{oparser.program_name} -w "foo(\\d+)" 'bar(\#{$1})'
  例4. 行末のスペースを削除するには？
    $ #{oparser.program_name} "\\s+$" "\\n"
  例5. func(1, 2) を func(2, 1) にするには？
    $ #{oparser.program_name} "func\\((.*?),(.*?)\\)" 'func(\#{$2},\#{$1})'
  例6. シングルクォーテーションをダブルクォーテーションに変換
    $ #{oparser.program_name} \"'\" \"\\\\\"\"
  例7. 半角カナも含めて全角カナにするには？
    $ #{oparser.program_name} --utf8 カナ かな
  例8. jQuery UIのテーマのCSSの中の url(images/xxx.png) を url(<%= asset_path("themes/(テーマ名)/images/xxx.png") %>) に置換するには？
    $ #{oparser.program_name} "\\burl\\(images/(\\S+?)\\)" 'url(<%= asset_path(\\"themes/\#{f.to_s.scan(/themes\\/(\\S+?)\\//).flatten.first}/images/\#{m[1]}\\") %>)'
  例9. test-unit → rspec への簡易変換
    $ #{oparser.program_name} \"class Test(.*) < Test::Unit::TestCase\" 'describe \#{$1} do'
    $ #{oparser.program_name} \"def test_(\\S+)\" 'it \\\"\#{$1}\\\" do'
    $ #{oparser.program_name} \"assert_equal\\((.*?), (.*?)\\)\" '\#{$2}.should == \#{$1}'
  例10. 1.8形式の require_relative 相当を 1.9 の require_relative に変換するには？
    $ #{oparser.program_name} \"require File.expand_path\\(File.join\\(File.dirname\\(__FILE__\\), \\\"(.*)\\\"\\)\\)\" \"require_relative '\#{\\$1}'\"
EOT
      end

      begin
        args = oparser.parse(args)
      rescue OptionParser::InvalidOption => error
        puts error
        usage(oparser)
      end

      src = args.shift
      dst = args.shift
      if src.nil? || dst.nil?
        usage(oparser)
      end

      if args.empty?
        args << "."
      end

      Saferep::Core.run(src, dst, args, options)
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
