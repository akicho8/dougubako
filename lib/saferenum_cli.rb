# -*- coding: utf-8 -*-
#
# ファイルを連番にリネームするスクリプト
#

require 'optparse'
require 'securerandom'
require 'fileutils'
require_relative 'file_filter'

module Saferenum
  VERSION = "1.0.0"

  class Core
    attr_reader :options
    attr_accessor :counts

    def self.run(*args, &block)
      new(*args, &block).run
    end

    def initialize(dirs, options)
      @dirs = dirs
      @options = options
      @counts = Hash.new(0)
    end

    def run
      @dirs.each{|dir|
        Runner.new(self, dir)
      }
      puts "差分:#{@counts[:diff]} ディレクトリ数:#{@counts[:diff]} ファイル数:#{@counts[:count]} 個を処理しました。"
      unless @options[:exec]
        puts "本当に実行するには -x オプションを付けてください。"
      end
    end

    private

    class Runner
      def initialize(base, dir)
        @base = base
        dir = Pathname(dir).expand_path
        all = dir.each_child                                  # すべてのファイルとディレクトリ
        all = all.reject{|e|e.basename.to_s.match(/\A[\._]/)} # . .. .git _ などで始まるものを消して必要なものだけに絞る
        all = reject(all)
        all = all.sort
        files = all.find_all{|entry|!entry.directory?}        # ファイルのみ
        dirs = all.find_all{|entry|entry.directory?}          # ディレクトリのみ

        # サブディレクトリを処理
        if @base.options[:recursive]
          dirs.each{|e|self.class.new(@base, e)}
        end

        unless @base.options[:all]
          # 更新する場合はすでに数値がついたものだけを対象にする
          files = files.find_all{|e|e.basename.to_s.match(/\A\d+/)}
        end

        if files.empty?
          return
        end

        run_core(dir, files)
      end

      private

      #
      # dir で files を処理する
      #
      def run_core(dir, files)
        puts "[DIR] #{dir} (#{files.size} files)"
        @base.counts[:dir] += 1

        if @base.options[:exec]
          tmpdir = Pathname("#{dir}/#{SecureRandom.hex}")
          FileUtils.mkdir(tmpdir, :noop => @base.options[:noop], :verbose => @base.options[:verbose])
        end

        if @base.options[:exec]
          FileUtils.mv(files, tmpdir, :noop => @base.options[:noop], :verbose => @base.options[:verbose])
        end

        files.each_with_index{|file, index|
          if @base.options[:number_only]
            rest = file.extname
          else
            md = file.basename.to_s.match(/\A(\d*)(?<rest>.*)/) or raise "ファイル名が 0123_foo.txt 形式じゃない"
            rest = md[:rest]
          end
          renamed_file = file.dirname + [number_format(files, index), rest].join
          mark = " "
          diff = false
          if file.basename.to_s != renamed_file.basename.to_s
            mark = "U"
            diff = true
            @base.counts[:diff] += 1
          end
          index_str = "[#{index.next.to_s.rjust(files.size.to_s.size)}/#{files.size}]"
          if diff || @base.options[:verbose]
            puts "  #{mark} #{index_str} #{file.basename} => #{renamed_file.basename}"
          end
          @base.counts[:count] += 1
          if @base.options[:exec]
            FileUtils.mv(tmpdir + file.basename, renamed_file, :noop => @base.options[:noop], :verbose => @base.options[:verbose])
          end
        }

        if @base.options[:exec]
          FileUtils.rmdir(tmpdir, :noop => @base.options[:noop], :verbose => @base.options[:verbose])
        end
      end

      #
      # ファイル名のプレフィクス
      #
      def number_format(files, index)
        width = (@base.options[:base] + files.size * @base.options[:step]).to_s.size
        i = @base.options[:base] + index * @base.options[:step]
        "%0*d" % [width + 1, i]
      end

      #
      # テンポラリファイルを除く
      #
      def reject(all)
        all = all.reject{|e|e.to_s.match(Regexp.union("#", "~", "%"))}
        all = all.reject{|e|e.to_s.match(/\.(elc)\z/)}
      end
    end
  end

  module CLI
    def self.execute(args)
      options = {
        # CLで指定できるもの
        :exec        => false,  # 本当に実行するか？
        :all         => false,  # true:全ファイルを処理する false:数字のついたものだけが対象
        :recursive   => false,  # サブディレクトリも対象にする
        :verbose     => false,  # 詳細表示
        :number_only => false,  # true:数字以外を消す false:数字以外を保持する
        :base        => 100,    # インデックスの最初
        :step        => 10,     # インデックスのステップ
        # CLで指定できないもの
        :noop        => $DEBUG, # デバッグ時は true にする
      }

      oparser = OptionParser.new do |oparser|
        oparser.version = VERSION
        oparser.banner = [
          "ファイルを連番にリネームするスクリプト #{oparser.ver}\n",
          "使い方: #{oparser.program_name} [オプション] 対象ディレクトリ...\n",
        ].join
        oparser.on_head("オプション:")
        oparser.on("-x", "--exec", "実際に実行する(デフォルト:#{options[:exec]})"){|v|options[:exec] = v}
        oparser.on("-r", "--recursive", "サブディレクトリも対象にする(デフォルト:#{options[:recursive]})"){|v|options[:recursive] = v}
        oparser.on("-a", "--all", "すべてのファイルを対象にする？(デフォルト:#{options[:all]})"){|v|options[:all] = v}
        oparser.on("-n", "--number-only", "番号だけにする？(デフォルト:#{options[:number_only]})"){|v|options[:number_only] = v}
        oparser.on("--base=INTEGER", "インデックスの最初(デフォルト:#{options[:base]})", Integer){|v|options[:base] = v}
        oparser.on("--step=INTEGER", "インデックスのステップ(デフォルト:#{options[:step]})", Integer){|v|options[:step] = v}
        oparser.on("-v", "--verbose", "詳細表示(デフォルト:#{options[:verbose]})"){|v|options[:verbose] = v}
        oparser.on("-h", "--help", "このヘルプを表示する"){puts oparser; abort}
        oparser.on(<<-EOT)

サンプル:
    例1. カレントディレクトリの《数字_名前.拡張子》形式のファイルを同じ形式でリナンバーする
        % #{oparser.program_name} .
    例2. 指定ディレクトリ以下のすべてのファイルを《数字.拡張子》形式にリネームする
        % #{oparser.program_name} -arn ~/Pictures/Archives
EOT
      end

      begin
        args = oparser.parse(args)
      rescue OptionParser::InvalidOption
        puts "オプションが間違っています。"
        abort
      end

      if args.empty?
        puts "使い方: #{oparser.program_name} [オプション] 対象ディレクトリ..."
        puts "`#{oparser.program_name} --help' でより詳しい情報を表示します。"
        abort
      end

      Saferenum::Core.run(args, options)
    end
  end
end

if $0 == __FILE__
  Saferenum::CLI.execute(["--recursive", "--all", "--number-only", "~/Pictures/renum"])
  # Saferenum::CLI.execute(["--all", "--number-only", "~/Pictures/がさいゆの"])
  # Saferenum::CLI.execute(["#{Pathname(__FILE__).dirname}/_pictures"])
  # Saferenum::CLI.execute(["-r", "#{Pathname(__FILE__).dirname}/_pictures"])
end
