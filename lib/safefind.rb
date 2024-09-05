# -*- coding: utf-8 -*-
# 関連ファイル検索ツール

require "pathname"
require_relative 'file_ignore'
require "fileutils"
require "optparse"

module Safefind
  class Core
    def self.run(*args)
      new(*args).run
    end

    def initialize(src, target_dirs, options)
      @options = options
      @target_dirs = target_dirs
      regexp_option = 0
      if @options[:ignocase]
        regexp_option |= Regexp::IGNORECASE
      end
      if options[:word]
        src = "[\\b_]#{src}[\\b_]"
      end
      @src_regexp = Regexp.compile(src, regexp_option)
      unless @options[:quiet]
        puts "検索情報:【#{@src_regexp.source}】(大小文字を区別#{@src_regexp.casefold? ? "しない" : "する"})"
      end
      @count = 0
    end

    def run
      @target_dirs.each do |target_dir|
        target_dir = Pathname(target_dir)
        target_dir.find do |fname|
          if FileIgnore.ignore?(fname, :include_directory => !@options[:file_only])
            next
          end
          execute(target_dir, fname)
        end
      end
      result_display
    end

    def execute(target_dir, fname)
      if @src_regexp.source.include?("/") || @options[:fullpath]
        # 検索ワードに / が含まれていたらベースネームではなくパスと比較するためそのままにする
        target = fname
      else
        if @options[:copy_to]
          target = fname.relative_path_from(target_dir)
        else
          target = fname.basename
        end
      end
      if md = @src_regexp.match(target.to_s)
        file_utils_options = {:noop => !@options[:exec], :verbose => true}
        case
        when @options[:copy_to]
          if @options[:rename_from] && @options[:rename_to]
            target = target.to_s.gsub(Regexp.escape(@options[:rename_from]), @options[:rename_to])
          end
          new_path = @options[:copy_to] + target
          unless new_path.dirname.exist?
            FileUtils.mkdir_p(new_path.dirname, **file_utils_options)
          end
          unless fname.directory?
            FileUtils.cp(fname, new_path, **file_utils_options)
          end
        when @options[:delete]
          FileUtils.rm_rf(fname.expand_path.to_s, **file_utils_options)
        else
          puts fname.expand_path
        end
        @count += 1
      end
    end

    def result_display
      return if @options[:quiet]
      puts "#{@count}ファイル見つかりました。"
      if @options[:exec]
        puts "本当に実行しました"
      end
    end
  end

  module CLI
    def self.execute(args)
      options = {
        :rename_from => nil,
        :rename_to   => nil,
        :file_only   => false,
        :fullpath    => false,
        :delete      => false,
      }

      oparser = OptionParser.new do |opts|
        opts.banner = [
          "関連ファイル検索 Version 2.0.0\n\n",
          "使い方: #{Pathname.new($0).basename} [オプション] 検索元 ファイル...\n\n",
        ].join
        opts.on_head("オプション")
        opts.on("-f", "--fullpath", "検索対象をフルパスにする(または/が含まれていれば有効になる)", TrueClass)  {|v| options[:fullpath] = v                      }
        opts.on("-i", "--ignore-case", "大小文字を区別しない")            {|v| options[:ignocase] = v                      }
        opts.on("-w", "--word-regexp", "単語とみなす")                    {|v| options[:word] = v                          }
        opts.on("-q", "--quiet", "必要な情報のみ表示")                    {|v| options[:quiet] = v                         }
        opts.on("-c", "--copy-to=DIRRECTORY", "ファイルをコピー", String) {|v| options[:copy_to] = Pathname(v).expand_path }
        opts.on("--file-only", "ファイルのみ", TrueClass)                 {|v| options[:file_only] = v                     }
        opts.on("--rename-from=STRING", "リネーム前", String)             {|v| options[:rename_from] = v                   }
        opts.on("--rename-to=STRING", "リネーム後", String)               {|v| options[:rename_to] = v                     }
        opts.on("--delete", "--rm", "ファイル削除", TrueClass)            {|v| options[:delete] = v                        }
        opts.on("-x", "--exec", "本当に実行する")                         {|v| options[:exec] = v                          }
        opts.on("--help", "このヘルプを表示する") {puts opts; abort}
      end

      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption
        puts "オプションが間違っています。"
        abort
      end

      src = args.shift
      if src.nil?
        puts "使い方: #{Pathname.new($0).basename} [オプション] <検索文字列> <ファイル or ディレクトリ>..."
        puts "`#{Pathname.new($0).basename} --help' でより詳しい情報を表示します。"
        abort
      end

      if args.empty?
        args << "."
      end

      Core.run(src, args, options)
    end
  end
end

if $0 == __FILE__
  Safefind::CLI.execute(ARGV)
end
