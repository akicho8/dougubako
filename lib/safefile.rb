# -*- coding: utf-8 -*-
# ファイル整形

require "pathname"
require "optparse"
require "diff/lcs"
require_relative "file_ignore"

module Safefile
  VERSION = "1.0.0"
  ZenkakuChars = "ａ-ｚＡ-Ｚ０-９（）／＊"
  ReplaceChars = "a-zA-Z0-9()/*"

  class Core
    def self.run(*args, &block)
      new(*args, &block).run
    end

    def initialize(files, options = {}, &block)
      @files = files
      @options = {
      }.merge(options)
      if block_given?
        yield self
      end
      @counts = Hash.new(0)
    end

    def run
      run_dir(@files)
      puts "#{@counts[:file]} 個のファイルの中から #{@counts[:success]} 個を置換しました。総diffは #{@counts[:diff]} 行です。"
      unless @options[:exec]
        puts "本当に置換するには -x オプションを付けてください。"
      end
    end

    private

    def run_dir(files)
      files = files.collect {|e| Pathname.glob(e) }.flatten # SHELLのファイル展開に頼らないで「*.rb」などを展開する
      files.each do |filename|
        filename = Pathname(filename).expand_path
        if @options[:recursive] && filename.directory?
          run_dir(filename.children)
          next
        end
        if ignore?(filename)
          next
        end
        replace(filename)
      end
    end

    def ignore?(filename)
      if FileIgnore.ignore?(filename)
        return true
      end
      if filename.basename.to_s.match(/\.min\./)
        return true
      end
      if ["development_structure.sql", "schema.rb"].include?(filename.basename.to_s)
        return true
      end
      false
    end

    def replace(filename)
      if @options[:windows]
        medhod = :tosjis
        ret_code = "\r\n"
      else
        medhod = :toutf8
        ret_code = "\n"
      end

      source = filename.read.public_send(medhod)
      lines = source.split(/\r\n|\r|\n/).collect do |line|
        if @options[:hankaku_space]
          line = line.gsub(/#{[0x3000].pack('U')}/, " ")
        end
        if @options[:hankaku]
          line = line.tr(ZenkakuChars, ReplaceChars)
        end
        if @options[:rstrip]
          line = line.rstrip
        else
          line = line.gsub(/[\r\n]+$/, "")
        end
        line
      end

      new_content = lines.join(ret_code)

      if @options[:delete_blank_lines]
        # 2行以上の空行を1行にする
        new_content = new_content.gsub(/(#{ret_code}){2,}/, '\1\1')
      end

      # 最後の空行を取る
      new_content = new_content.rstrip + ret_code

      # 固まっている重複行を一つにする
      #
      #   b a a b b a => b a b a
      #
      if @options[:uniq]
        lines = new_content.lines.to_a
        lines.each_with_index do |line, i|
          if line == lines[i.next]
            lines[i] = nil
          end
        end
        new_content = lines.compact.join
      end

      # コンテンツが改行しかないのなら空にする
      if new_content.match(/\A#{ret_code}\z/)
        new_content = ""
      end

      mark = nil
      desc = nil
      count = Diff::LCS.sdiff(source.lines.to_a, new_content.lines.to_a).count {|e| e.action == "!" }
      @counts[:diff] += count
      @counts[:file] += 1
      if count >= 1 || @options[:force]
        @counts[:success] += 1
        mark = "U"
        desc = "(#{count} diffs)"
        if @options[:exec]
          filename.write(new_content)
        end
      end
      if mark
        puts "#{mark} #{filename} #{desc}".rstrip
      end
      if @options[:diff]
        diff_display(filename, source, new_content)
      end
    end

    def diff_display(filename, old_content, new_content)
      diffs = Diff::LCS.sdiff(old_content.lines.to_a, new_content.lines.to_a) # すべての行のdiffをとる
      diffs = diffs.find_all {|e| e.old_element != e.new_element }               # 異なる行だけに絞る
      diffs.each_with_index do |diff, index|
        puts "-------------------------------------------------------------------------------- [#{index.next}/#{diffs.size}]"
        puts "#{filename}:#{diff.old_position.next}: - #{diff.old_element.lstrip}" if diff.old_element
        puts "#{filename}:#{diff.new_position.next}: + #{diff.new_element.lstrip}" if diff.new_element
        puts "--------------------------------------------------------------------------------" if diffs.last == diff
      end
    end
  end
end

module Safefile
  module CLI
    def self.execute(args)
      options = {
        :delete_blank_lines => true,
        :hankaku_space      => true,
        :hankaku            => true,
        :diff               => false,
        :uniq               => false,
        # :quiet            => false,
        :windows            => false,
        :rstrip             => true,
        :recursive          => false,
      }

      oparser = OptionParser.new do |opts|
        opts.version = VERSION
        opts.banner = [
          "ファイル整形 #{opts.ver}\n",
          "使い方: #{opts.program_name} [オプション] ディレクトリ or ファイル...\n",
        ].join
        opts.on("オプション:")
        opts.on("-x", "--exec", "本当に置換する") {|v| options[:exec] = v }
        opts.on("-r", "--recursive", "サブディレクトリも対象にする(デフォルト:#{options[:recursive]})") {|v| options[:recursive] = v }
        opts.on("-s", "--[no-]rstrip", "rstripする(#{options[:rstrip]})") {|v| options[:rstrip] = v }
        opts.on("-b", "--[no-]delete-blank-lines", "2行以上の空行を1行にする(#{options[:delete_blank_lines]})") {|v| options[:delete_blank_lines] = v }
        opts.on("-z", "--[no-]hankaku", "「#{ZenkakuChars}」を半角にする(#{options[:hankaku]})") {|v| options[:hankaku] = v }
        opts.on("-Z", "--[no-]hankaku-space", "全角スペースを半角スペースにする(#{options[:hankaku_space]})") {|v| options[:hankaku_space] = v }
        opts.on("-d", "--[no-]diff", "diffの表示(#{options[:diff]})") {|v| options[:diff] = v }
        opts.on("-u", "--[no-]uniq", "同じ行が続く場合は一行にする(#{options[:uniq]})") {|v| options[:uniq] = v }
        opts.on("-w", "--windows", "SHIFT-JISで改行も CR + LF にする(#{options[:windows]})") {|v| options[:windows] = v }
        opts.on("-f", "--force", "強制置換する") {|v| options[:force] = v }
        # opts.on("-q", "--quiet", "静かにする(#{options[:quiet]})") {|v| options[:quiet] = v }
        opts.on(<<-EOT)
使用例:
    1. カレントディレクトリのすべてのファイルを整形する
      $ #{opts.program_name} .
    2. サブディレクトリを含め、diffで整形結果を確認する
      $ #{opts.program_name} -rd .
    3. カレントの *.bat のファイルをWindows用に置換する
      $ #{opts.program_name} -w *.bat
    4. UTF-8にするだけ
      $ #{opts.program_name} --no-rstrip --no-delete-blank-lines --no-hankaku --no-hankaku-space --no-uniq *.kif
EOT
      end

      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption => error
        puts error
        abort
      end

      if args.empty?
        puts "使い方: #{oparser.program_name} [オプション] ディレクトリ or ファイル..."
        puts "`#{oparser.program_name} --help' でより詳しい情報を表示します。"
        abort
      end

      Safefile::Core.run(args, options)
    end
  end
end

if $0 == __FILE__
  # Safefile::CLI.execute(["-rdfzZ", "safe*.rb"])
  Safefile::CLI.execute(["-du", "_test.txt"])
end
