# -*- coding: utf-8 -*-
# ファイル削除ツール

require "pathname"
require_relative 'file_ignore'
require "fileutils"
require "optparse"

module Saferm
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
          if FileIgnore.ignore?(fname)
            next
          end
          if @src_regexp.match(fname.basename.to_s)
            FileUtils.rm_rf(fname.expand_path.to_s, {:noop => !@options[:exec], :verbose => true})
          end
          @count += 1
        end
      end
      result_display
    end

    def result_display
      if @options[:exec]
        puts "本当に実行しました"
      end
    end
  end

  module CLI
    def self.execute(args)
      options = {}
      oparser = OptionParser.new do |opts|
        opts.banner = [
          "ファイル削除 Version 1.0.0\n\n",
          "使い方: #{Pathname.new($0).basename} [オプション] 検索元 ファイル...\n\n",
        ].join
        opts.on_head("オプション")
        opts.on("-i", "--ignore-case", "大小文字を区別しない") {|v| options[:ignocase] = v }
        opts.on("-w", "--word-regexp", "単語とみなす") {|v| options[:word] = v }
        opts.on("-x", "--exec", "本当に実行する") {|v| options[:exec] = v }
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
  Saferm::CLI.execute(ARGV)
end
