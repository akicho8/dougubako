# -*- coding: utf-8 -*-
#
# 関連ファイル検索ツール
#

require "pathname"
require File.expand_path(File.join(File.dirname(__FILE__), "ignore_checker"))
require "fileutils"
require "optparse"

module SimpleFinder
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
      @srcreg = Regexp.compile(src, regexp_option)
      unless @options[:quiet]
        puts "検索情報:【#{@srcreg.source}】(大小文字を区別#{@srcreg.casefold? ? "しない" : "する"})"
      end
      @count = 0
    end

    def run
      @target_dirs.each do |target_dir|
        target_dir = Pathname(target_dir)
        target_dir.find do |fname|
          if IgnoreChecker.ignore_file?(fname, :include_directory => !@options[:file_only])
            next
          end
          execute(target_dir, fname)
        end
      end
      result_display
    end

    def execute(basepath, fname)
      if @srcreg.source.include?("/") || @options[:fullpath]
        # 検索ワードに / が含まれていたらベースネームではなくパスと比較するためそのままにする
        target = fname
      else
        if @options[:copy_to]
          target = fname.relative_path_from(basepath)
        else
          target = fname.basename
        end
      end
      if md = @srcreg.match(target.to_s)
        file_utils_options = {:noop => !@options[:exec], :verbose => true}
        if @options[:copy_to]
          if @options[:rename_from] && @options[:rename_to]
            target = target.to_s.gsub(Regexp.escape(@options[:rename_from]), @options[:rename_to])
          end
          new_path = @options[:copy_to] + target
          unless new_path.dirname.exist?
            FileUtils.mkdir_p(new_path.dirname, file_utils_options)
          end
          unless fname.directory?
            FileUtils.cp(fname, new_path, file_utils_options)
          end
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
        puts "#{@options[:copy_to]} にコピーしました。"
      end
    end
  end
end

module SimpleFinder
  module CLI
    def self.execute(args)
      options = {
        :rename_from => nil,
        :rename_to => nil,
        :file_only => false,
        :fullpath => false,
      }

      oparser = OptionParser.new do |oparser|
        oparser.banner = [
          "関連ファイル検索スクリプト Version 2.0.0\n\n",
          "使い方: #{Pathname.new($0).basename} [オプション] 検索元 ファイル...\n\n",
        ]
        oparser.on_head("オプション")
        oparser.on("-f", "--fullpath", "検索対象をフルパスにする(または/が含まれていれば有効になる)", TrueClass) {|options[:fullpath]|}
        oparser.on("-i", "--ignore-case", "大小文字を区別しない") {|options[:ignocase]|}
        oparser.on("-w", "--word-regexp", "単語とみなす") {|options[:word]|}
        oparser.on("-q", "--quiet", "必要な情報のみ表示") {|options[:quiet]|}
        oparser.on("-c", "--copy-to=DIRRECTORY", "ファイルをコピー", String) {|copy_to|options[:copy_to] = Pathname(copy_to).expand_path}
        oparser.on("--file-only", "ファイルのみ", TrueClass) {|options[:file_only]|}
        oparser.on("--rename-from=STRING", "リネーム前", String) {|options[:rename_from]|}
        oparser.on("--rename-to=STRING", "リネーム後", String) {|options[:rename_to]|}
        oparser.on("-x", "--exec", "本当に実行する") {|options[:exec]|}
        oparser.on_tail("--help", "このヘルプを表示する") {puts oparser; abort}
      end

      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption
        puts "オプションが間違っています。"
        abort
      end

      src = args.shift
      if src.nil?
        puts "使い方: #{Pathname.new($0).basename} [オプション] 検索文字列 ファイル..."
        puts "`#{Pathname.new($0).basename} --help' でより詳しい情報が表示されます。"
        abort
      end

      if args.empty?
        args << "."
      end

      SimpleFinder::Core.run(src, args, options)
    end
  end
end

if $0 == __FILE__
  SimpleFinder::CLI.execute(ARGV)
end
