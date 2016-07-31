# -*- coding: utf-8 -*-
# ファイル整形

require "bundler/setup"

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

    attr_accessor :options, :counts

    def initialize(files, options = {}, &block)
      @files = files

      @options = {
      }.merge(options)

      @counts = Hash.new(0)
    end

    def run
      dir_walk(@files)
      puts "#{@counts[:file]} 個のファイルの中から #{@counts[:success]} 個を置換しました。総diffは #{@counts[:diff]} 行です。"
      unless @options[:exec]
        puts "本当に置換するには -x オプションを付けてください。"
      end
    end

    private

    def dir_walk(files)
      files = files.collect {|e| Pathname.glob(e) }.flatten # SHELLのファイル展開に頼らないで「*.rb」などを展開する
      files.each do |e|
        e = e.expand_path
        if e.directory?
          if @options[:recursive]
            dir_walk(e.children)
          end
          next
        end
        replacer = Replacer.new(self, e)
        if replacer.ignore?
          next
        end
        replacer.replace
      end
    end

    class Replacer
      def initialize(base, current_file)
        @base = base
        @current_file = current_file
      end

      def ignore?
        if FileIgnore.ignore?(@current_file)
          return true
        end
        if @current_file.basename.to_s.match(/\.min\./)
          return true
        end
        if ["development_structure.sql", "schema.rb"].include?(@current_file.basename.to_s)
          return true
        end
        false
      end

      def replace
        @source = @current_file.read.public_send(toxxxx)
        @body = @source.dup

        @body = @body.split(/\R/).collect { |e|
          if @base.options[:hankaku_space]
            e.gsub!(/#{[0x3000].pack('U')}/, " ")
          end
          if @base.options[:hankaku]
            e.tr!(ZenkakuChars, ReplaceChars)
          end
          if @base.options[:rstrip]
            e.rstrip!
          else
            e.gsub!(/\R+$/, "")
          end
          e
        }.join(enter_code)

        if @base.options[:delete_blank_lines]
          # 2行以上の空行を1行にする
          @body = @body.gsub(/(#{enter_code}){2,}/, '\1\1')
        end

        # 先頭と最後の空行を取る
        @body = @body.strip + enter_code

        # 固まっている重複行を一つにする
        #
        #   b a a b b a => b a b a
        #
        if @base.options[:uniq]
          lines = @body.lines.to_a
          lines.each_with_index do |e, i|
            if e == lines[i.next]
              lines[i] = nil
            end
          end
          @body = lines.compact.join
        end

        # 最後に内容が空に見えるなら完全に空にする
        @body.gsub!(/\A[[:space:]]*\z/, "")

        mark = nil
        desc = nil
        @base.counts[:diff] += diffs.count
        @base.counts[:file] += 1

        if diffs.count >= 1 || @base.options[:force]
          @base.counts[:success] += 1
          mark = "U"
          desc = "(#{diffs.count} diffs)"
          if @base.options[:exec]
            @current_file.write(@body)
          end
        end

        if mark
          puts "#{mark} #{@current_file} #{desc}".rstrip
        end

        if @base.options[:diff]
          diff_display
        end
      end

      def diffs
        @diffs ||= Diff::LCS.sdiff(@source.lines, @body.lines).find_all do |e|
          # e.action == "!" ではダメ
          e.old_element != e.new_element
        end
      end

      def diff_display
        diffs.each_with_index do |e, i|
          puts "-------------------------------------------------------------------------------- [#{i.next}/#{diffs.size}]"
          puts "#{@current_file}:#{e.old_position.next}: - #{e.old_element.inspect}" if e.old_element
          puts "#{@current_file}:#{e.new_position.next}: + #{e.new_element.inspect}" if e.new_element
          puts "--------------------------------------------------------------------------------" if diffs.last == e
        end
      end

      def toxxxx
        if @base.options[:windows]
          :tosjis
        else
          :toutf8
        end
      end

      def enter_code
        if @base.options[:windows]
          "\r\n"
        else
          "\n"
        end
      end
    end
  end

  module CLI
    def self.execute(args)
      options = {
        :delete_blank_lines => true,
        :hankaku_space      => true,
        :hankaku            => true,
        :diff               => false,
        :uniq               => false,
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
        opts.on("-x", "--exec", "本当に置換する")                                                               {|v| options[:exec] = v                }
        opts.on("-r", "--recursive", "サブディレクトリも対象にする(デフォルト:#{options[:recursive]})")         {|v| options[:recursive] = v           }
        opts.on("-s", "--[no-]rstrip", "rstripする(#{options[:rstrip]})")                                       {|v| options[:rstrip] = v              }
        opts.on("-b", "--[no-]delete-blank-lines", "2行以上の空行を1行にする(#{options[:delete_blank_lines]})") {|v| options[:delete_blank_lines] = v  }
        opts.on("-z", "--[no-]hankaku", "「#{ZenkakuChars}」を半角にする(#{options[:hankaku]})")                {|v| options[:hankaku] = v             }
        opts.on("-Z", "--[no-]hankaku-space", "全角スペースを半角スペースにする(#{options[:hankaku_space]})")   {|v| options[:hankaku_space] = v       }
        opts.on("-d", "--[no-]diff", "diffの表示(#{options[:diff]})")                                           {|v| options[:diff] = v                }
        opts.on("-u", "--[no-]uniq", "同じ行が続く場合は一行にする(#{options[:uniq]})")                         {|v| options[:uniq] = v                }
        opts.on("-w", "--windows", "SHIFT-JISで改行も CR + LF にする(#{options[:windows]})")                    {|v| options[:windows] = v             }
        opts.on("-f", "--force", "強制置換する")                                                                {|v| options[:force] = v               }
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

      Core.run(args, options)
    end
  end
end

if $0 == __FILE__
  # Safefile::CLI.execute(["-rdfzZ", "safe*.rb"])
  Safefile::CLI.execute(["-du", "_test.txt"])
end
