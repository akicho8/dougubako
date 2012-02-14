# -*- coding: utf-8 -*-
# -*- compile-command: "ruby test_saferep.rb -v" -*-
# テキストファイル置換ツール

require "optparse"
require "timeout"
require_relative 'file_filter'

module Saferep
  VERSION = "2.0.3"

  class Core
    def self.run(*args)
      new(*args).run
    end

    def initialize(src, dst, files, options)
      @src = src
      @dst = dst
      @files = files
      @options = {
        :timeout => 1.0,
      }.merge(options)

      @log = []
      @replace_count = 0
      @backup_dir = Pathname("~/tmp").expand_path
      @fetch_count = 0
      @line_count = 0
      @stop = false

      if @options.key?(:simple_text) && (@options[:simple_text].nil? || @options[:simple_text] == "1")
        p "escape 1" if $DEBUG
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
            @fetch_count += 1
            if @options[:debug]
              puts "find: #{fname.expand_path}"
            end
            result = true
            begin
              timeout(@options[:timeout]) {
                result = FileFilter.ignore_file?(fname)
              }
            rescue Timeout::Error
              puts "【警告】#{fname} の読み込みに時間がかかりすぎです。"
              result = true
            end
            if result || fname.basename.to_s.match(/(ChangeLog|\.diff)$/i)
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
      result_display
    end

    private

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
          #  p [new_line, @srcreg, new_line.match(@srcreg)]
          if new_line.gsub!(@srcreg) {
              m = match = __MATCH__ = Regexp.last_match
              count += 1
              if @options.key?(:simple_text) && (@options[:simple_text].nil? || @options[:simple_text] == "2")
                p "escape 2" if $DEBUG
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
        end
        out << new_line
      }
      if count > 0
        @log << "#{fname} (changed #{count})"
      end
      if @options[:exec]
        if count > 0
          bak = backupfile(fname)
          fname.rename(bak)
          if bak.exist?
            out = out.join
            if guess
              out = Kconv.kconv(out.join, guess, NKF::UTF8)
            end
            fname.open("w"){|f|f << out}
            # 権限復旧
            fname.chmod(bak.stat.mode)
          end
        end
      end
      @replace_count += count
    end

    def result_display
      unless @log.empty?
        puts
        puts @log.join("\n")
      end
      puts
      puts "結果: #{@log.size} 個のファイルの計 #{@replace_count} 個所を置換しました。(フェッチ数: #{@fetch_count})"
      unless @options[:exec]
        puts
        puts "本当に置換するには -x オプションを付けてください。"
      end
    end

    def backupfile(fname)
      @backup_dir.mkpath unless @backup_dir.exist?
      ext = ".000"
      loop {
        bak = @backup_dir.join(fname.basename.to_s + ext)
        break bak unless bak.exist?
        ext.succ!
      }
    end
  end

  module CLI
    def self.execute(args)
      options = {
        :toutf8 => false,
      }
      oparser = OptionParser.new do |oparser|
        oparser.version = VERSION
        oparser.banner = [
          "テキストファイル置換スクリプト #{oparser.ver}\n",
          "使い方: #{oparser.program_name} [オプション] <置換前> <置換後> <ファイル or ディレクトリ>...\n"
        ].join
        oparser.on("オプション:")
        oparser.on("-x", "--exec", "本当に置換する"){|v|options[:exec] = v}
        oparser.on("-i", "--ignore-case", "大小文字を区別しない"){|v|options[:ignocase] = v}
        oparser.on("-w", "--word-regexp", "単語とみなす"){|v|options[:word] = v}
        oparser.on("-s", "--simple-string=[1|2]", "置換文字列をエスケープ。片方のみの指定も可能(1:置換前 2:置換後)"){|v|options[:simple_text] = v}
        oparser.on("-d", "--debug", "デバッグ"){|v|options[:debug] = v}
        oparser.on("-g", "--guess", "文字コードをNKF.guessで判断する(デフォルトはすべてUTF-8とみなす)"){|v|options[:guess] = v}
        oparser.on("--sjis", "文字コードをすべてsjisとする"){|v|options[:sjis] = v}
        oparser.on("-u", "--[no-]utf8", "内部でtoutf8した結果に対して置換する(旧デフォルト。ハンカクカナが全角カナになる。初期値:#{options[:toutf8]})"){|v|options[:toutf8] = v}
        oparser.on("--head=N", "先頭のn行のみが対象", Integer){|v|options[:head] = v}
        oparser.on("--limit=N", "N個置換したら打ち切る", Integer){|v|options[:limit] = v}
        oparser.on("--help", "このヘルプを表示する"){puts oparser; abort}
        oparser.on(<<-EOT)
サンプル:

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

  例6. jQuery UIのテーマのCSSの中の url(images/xxx.png) を url(<%= asset_path("themes/(テーマ名)/images/xxx.png") %>) に置換するには？
    $ #{oparser.program_name} "\\burl\\(images/(\\S+?)\\)" 'url(<%= asset_path(\\"themes/\#{f.to_s.scan(/themes\\/(\\S+?)\\//).flatten.first}/images/\#{m[1]}\\") %>)'

  例7. test-unit → rspec への簡易変換
    $ #{oparser.program_name} \"class Test(.*) < Test::Unit::TestCase\" 'describe \#{$1} do'
    $ #{oparser.program_name} \"def test_(\\S+)\" 'it \\\"\#{$1}\\\" do'
    $ #{oparser.program_name} \"assert_equal\\((.*?), (.*?)\\)\" '\#{$2}.should == \#{$1}'

  例8. 1.8形式の require_relative 相当を 1.9 の require_relative に変換するには？
    $ #{oparser.program_name} \"require File.expand_path\\(File.join\\(File.dirname\\(__FILE__\\), \\\"(.*)\\\"\\)\\)\" \"require_relative '\#{\\$1}'\"

  例9. 半角カナが含まれるファイルの置換を行ったときに半角カナが全角カナになるのを防ぐには？
    $ #{oparser.program_name} --raw foo bar
EOT
      end

      begin
        args = oparser.parse(args)
      rescue OptionParser::InvalidOption
        puts "オプションが間違っています。"
        abort
      end

      src = args.shift
      dst = args.shift
      if src.nil? || dst.nil?
        puts "使い方: #{oparser.program_name} [オプション] <置換前> <置換後> <ファイル or ディレクトリ>..."
        puts "`#{oparser.program_name} --help' でより詳しい情報を表示します。"
        abort
      end

      if args.empty?
        args << "."
      end

      Saferep::Core.run(src, dst, args, options)
    end
  end
end

if $0 == __FILE__
  Saferep::CLI.execute(ARGV)
end
