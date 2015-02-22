# -*- coding: utf-8 -*-
#
# ファイル名リナンバー
#

require 'optparse'
require 'securerandom'
require 'fileutils'
require_relative 'file_ignore'

module Saferenum
  VERSION = "1.1.1".freeze

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
      @dirs.each do |dir|
        Runner.new(self, dir)
      end
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
        all = dir.children                                    # すべてのファイルとサブディレクトリ
        all = reject_files(all)
        all = all.sort                                        # TODO:数値としてソートする機能を入れる
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
          if @base.options[:reject_basename]
            # "0123_foo.txt" から ".txt" の部分を取得
            rest = file.extname
          else
            # "0123_foo.txt" から "_foo.txt" の部分を取得
            md = file.basename.to_s.match(/\A(\d*)(?<rest>.*)/) or raise "ファイル名が 0123_foo.txt 形式ではありません"
            rest = md[:rest]
          end
          # "0100" + "_foo.txt" または "0100" + ".txt" となる
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
      # ファイル名のプレフィクスを取得
      #
      def number_format(files, index)
        width = (@base.options[:base] + files.size * @base.options[:step]).to_s.size
        i = @base.options[:base] + index * @base.options[:step]
        if @base.options[:number_only]
          "%d" % i
        else
          "%0*d" % [width + @base.options[:zero], i]
        end
      end

      #
      # 不要なファイルやディレクトリを除外する
      #
      def reject_files(all)
        all = all.reject {|e| e.basename.to_s.match(/\A[\._]/) }           # .svn .git _* などを除外
        all = all.reject {|e| e.to_s.match(Regexp.union("#", "~", "%")) }  # テンポラリファイルを除外
        all = all.reject {|e| e.to_s.match(/\.(elc)\z/) }
      end
    end
  end

  module CLI
    def self.execute(args)
      options = {
                                    # CLで指定できるもの
        :exec            => false,  # 本当に実行するか？
        :all             => false,  # true:全ファイルを処理する false:番号のついたものだけが対象
        :recursive       => false,  # サブディレクトリも対象にする
        :verbose         => false,  # 詳細表示
        :reject_basename => false,  # true:番号以外を消す false:番号以外を保持する
        :base            => 100,    # インデックスの最初
        :step            => 10,     # インデックスのステップ
        :zero            => 1,      # 幅の余白
        :number_only     => false,  # 番号だけにする
                                    # CLで指定できないもの
        :noop            => $DEBUG, # デバッグ時は true にする
      }

      oparser = OptionParser.new do |opts|
        opts.version = VERSION
        opts.banner = [
          "ファイル名リナンバー #{opts.ver}\n",
          "使い方: #{opts.program_name} [オプション] 対象ディレクトリ...\n",
        ].join
        opts.on_head("オプション:")
        opts.on("-x", "--exec", "実際に実行する(デフォルト:#{options[:exec]})") {|v| options[:exec] = v }
        opts.on("-r", "--recursive", "サブディレクトリも対象にする(デフォルト:#{options[:recursive]})") {|v| options[:recursive] = v }
        opts.on("-a", "--all", "すべてのファイルを対象にする？(デフォルト:#{options[:all]})") {|v| options[:all] = v }
        opts.on("-c", "--reject-basename", "ベースネームを捨てる？(デフォルト:#{options[:reject_basename]})") {|v| options[:reject_basename] = v }
        opts.on("-b", "--base=INTEGER", "インデックスの最初(デフォルト:#{options[:base]})", Integer) {|v| options[:base] = v }
        opts.on("-s", "--step=INTEGER", "インデックスのステップ(デフォルト:#{options[:step]})", Integer) {|v| options[:step] = v }
        opts.on("-z", "--zero=INTEGER", "先頭に入れる0の数(デフォルト:#{options[:zero]})", Integer) {|v| options[:zero] = v }
        opts.on("-n", "--number-only", "ゼロパディングせず番号のみにする(デフォルト:#{options[:number_only]})", TrueClass) {|v| options[:number_only] = v }
        opts.on("-v", "--verbose", "詳細表示(デフォルト:#{options[:verbose]})") {|v| options[:verbose] = v }
        opts.on("-h", "--help", "このヘルプを表示する"){puts opts; abort}
        opts.on(<<-EOT)
サンプル:
    例1. カレントディレクトリの《番号_名前.拡張子》形式のファイルを同じ形式でリナンバーする
        % #{opts.program_name} .
    例2. 指定ディレクトリ以下のすべてのファイルを《番号.拡張子》形式にリネームする
        % #{opts.program_name} -rac ~/Pictures/Archives
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
  Saferenum::CLI.execute(["--recursive", "--all", "--reject-basename", "~/Pictures/Archives"])
  # Saferenum::CLI.execute(["--all", "--reject-basename", "~/Pictures/Archives/アルパカ"])
  # Saferenum::CLI.execute(["#{Pathname(__FILE__).dirname}/_pictures"])
  # Saferenum::CLI.execute(["-r", "#{Pathname(__FILE__).dirname}/_pictures"])
end
