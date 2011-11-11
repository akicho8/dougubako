# -*- coding: utf-8 -*-
# 文字列検索ツール

require "optparse"
require File.expand_path(File.join(File.dirname(__FILE__), "simple_grep_core"))

module SimpleGrep
  module CLI
    def self.execute(args)
      options = {
        :no_comment_skip => false,
        :debug => false,
      }

      oparser = OptionParser.new do |oparser|
        oparser.version = "2.0.0"
        oparser.banner = [
          "文字列検索スクリプト #{oparser.ver}\n\n",
          "使い方: #{oparser.program_name} [オプション] 検索元 ファイル...\n\n",
        ]
        oparser.on_head("オプション")
        oparser.on
        oparser.on("-i", "--ignore-case", "大小文字を区別しない") {|options[:ignocase]|}
        oparser.on("-w", "--word-regexp", "単語とみなす") {|options[:word]|}
        oparser.on("-s", "検索文字列をエスケープ") {|options[:escape]|}
        oparser.on("-a", "#で始まる行をスキップしない"){|options[:no_comment_skip]|}
        oparser.on("-d", "--debug" "デバッグモード", TrueClass){|options[:debug]|}
        oparser.on_tail("--help", "このヘルプを表示する") {puts oparser; exit(1)}
      end

      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption
        puts "オプションが間違っています。"
        exit(1)
      end

      if args.empty?
        puts "使い方: #{oparser.program_name} [オプション] 検索文字列 ファイル..."
        puts "`#{oparser.program_name} --help' でより詳しい情報が表示されます。"
        abort
      end

      src = args.shift

      if args.empty?
        args << "."
      end

      SimpleGrep::Core.run(src, args, options)
    end
  end
end

if $0 == __FILE__
  SimpleGrep::CLI.execute(ARGV)
end
