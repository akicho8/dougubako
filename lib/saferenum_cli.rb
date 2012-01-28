# -*- coding: utf-8 -*-
#
# ファイルを連番にリネームするスクリプト
#

require 'optparse'
require 'securerandom'
require 'fileutils'
require_relative 'ignore_checker'

module Saferenum
  class Core
    def self.run(*args, &block)
      new(*args, &block).run
    end

    def initialize(target_dirs, options)
      @target_dirs = target_dirs
      @options = options
    end

    def run
      @target_dirs.each{|target_dir|
        run_dir(target_dir)
      }
      puts
      if @options[:exec]
        puts "実行完了"
      else
        puts "本当に実行するには -x オプションを付けてください"
      end
    end

    private

    def run_dir(dir)
      dir = Pathname(dir).expand_path
      all_files = target_file_and_dir(dir)                 # すべてのファイルとディレクトリ
      files = all_files.find_all{|entry|!entry.directory?} # ファイルのみ
      dirs = all_files.find_all{|entry|entry.directory?}   # ディレクトリのみ

      # サブディレクトリを処理
      if @options[:recursive]
        dirs.each{|e|run_dir(e)}
      end

      if @options[:all]
      else
        # 更新する場合はすでに数値がついたものだけを対象にする
        files = files.find_all{|e|e.basename.to_s.match(/\A\d+/)}
      end

      if files.size.zero?
        return
      else
        puts "[DIR] #{dir} (#{files.size} files)"
      end

      run_core(dir, files)
    end

    #
    # dir で files を処理する
    #
    def run_core(dir, files)
      if @options[:exec]
        tmpdir = dir + SecureRandom.hex
        FileUtils.mkdir(tmpdir, :noop => @options[:noop], :verbose => @options[:verbose])
      end

      if @options[:exec]
        FileUtils.mv(files, tmpdir, :noop => @options[:noop], :verbose => @options[:verbose])
      end

      files.each_with_index{|file, index|
        if @options[:number_only]
          rest = file.extname
        else
          md = file.basename.to_s.match(/\A(\d*)(?<rest>.*)/) or raise "ファイル名が 0123_foo.txt 形式じゃない"
          rest = md[:rest]
        end
        renamed_file = file.dirname + [number_format(files, index), rest].join
        puts "      [#{index.next}/#{files.size}]  #{file.basename} => #{renamed_file.basename}"
        if @options[:exec]
          FileUtils.mv(tmpdir + file.basename, renamed_file, :noop => @options[:noop], :verbose => @options[:verbose])
        end
      }

      if @options[:exec]
        FileUtils.rmdir(tmpdir, :noop => @options[:noop], :verbose => @options[:verbose])
      end
    end

    #
    # ファイル名のプレフィクス
    #
    def number_format(files, index)
      width = (@options[:base] + files.size * @options[:step]).to_s.size
      i = @options[:base] + index * @options[:step]
      "%0*d" % [width + 1, i]
    end

    def target_file_and_dir(dir)
      # . .. .git _ などで始まるものを消して必要なものだけに絞る
      files = dir.entries.reject{|entry|entry.to_s.match(/\A[\._]/)}.sort

      # そのままだと directory? が使えなかったりと扱いにくいので絶対パスにする
      files = files.collect{|entry|dir + entry}
    end
  end

  module CLI
    def self.execute(args)
      options = {
        # CLで指定できるもの
        :all         => false,  # true:全ファイルを処理する false:数字のついたものだけが対象
        :recursive   => false,  # サブディレクトリも対象にする
        :verbose     => false,  # 詳細表示
        :number_only => false,  # true:数字以外を消す false:数字以外を保持する
        :base        => 100,    # インデックスの最初
        :step        => 10,     # インデックスのステップ
        # CLで指定できないもの
        :noop        => true,  # デバッグ時は true にする
      }

      oparser = OptionParser.new do |oparser|
        oparser.version = "2.0.0"
        oparser.banner = [
          "ファイルを連番にリネームするスクリプト #{oparser.ver}\n\n",
          "使い方: #{oparser.program_name} [オプション] [オプション] 対象ディレクトリ...\n\n",
        ].join
        oparser.on_head("オプション")
        oparser.on
        oparser.on("-x", "--exec", "実際に実行する") {|v|options[:exec] = v}
        oparser.on("-r", "--recursive", "サブディレクトリも対象にする(デフォルト:#{options[:recursive]})") {|v|options[:recursive] = v}
        oparser.on("-a", "--all", "すべてのファイルを対象にする？(デフォルト:#{options[:all]})") {|v|options[:all] = v}
        oparser.on("-n", "--number-only", "番号だけにする？(デフォルト:#{options[:number_only]})") {|v|options[:number_only] = v}
        oparser.on("--base=INTEGER", "インデックスの最初(デフォルト:#{options[:base]})", Integer) {|v|options[:base] = v}
        oparser.on("--step=INTEGER", "インデックスのステップ(デフォルト:#{options[:step]})", Integer) {|v|options[:step] = v}
        oparser.on("-v", "--verbose", "詳細表示(デフォルト:#{options[:verbose]})") {|v|options[:verbose] = v}
        oparser.on_tail("-h", "--help", "このヘルプを表示する") {puts oparser; abort}
      end

      begin
        args = oparser.parse(args)
      rescue OptionParser::InvalidOption
        puts "オプションが間違っています。"
        abort
      end

      if args.empty?
        puts oparser
        abort
      end

      Saferenum::Core.run(args, options)
    end
  end
end

if $0 == __FILE__
  Saferenum::CLI.execute(["--all", "--number-only", "~/Pictures/がさいゆの"])
  Saferenum::CLI.execute(["#{Pathname(__FILE__).dirname}/_pictures"])
  Saferenum::CLI.execute(["-r", "#{Pathname(__FILE__).dirname}/_pictures"])
end
