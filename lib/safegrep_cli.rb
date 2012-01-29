# -*- coding: utf-8 -*-
#
# 文字列検索ツール
#

require 'optparse'
require_relative 'safegrep_core'

module Safegrep
  VERSION = '2.0.1'.freeze

  module CLI
    def self.execute(args)
      options = {
        :no_comment_skip => false,
        :debug => false,
      }

      oparser = OptionParser.new do |oparser|
        oparser.version = VERSION
        oparser.banner = [
          "文字列検索スクリプト #{oparser.ver}\n",
          "使い方: #{oparser.program_name} [オプション] 検索元 ファイル...\n",
        ].join
        oparser.on("オプション:")
        oparser.on("-i", "--ignore-case", "大小文字を区別しない") {|v|options[:ignocase] = v}
        oparser.on("-w", "--word-regexp", "単語とみなす") {|v|options[:word] = v}
        oparser.on("-s", "検索文字列をエスケープ") {|v|options[:escape] = v}
        oparser.on("-a", "#で始まる行をスキップしない"){|v|options[:no_comment_skip] = v}
        oparser.on("-d", "--debug", "デバッグモード"){|v|options[:debug] = v}
        oparser.on("--help", "このヘルプを表示する") {puts oparser; abort}
      end

      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption
        puts "オプションが間違っています"
        abort
      end

      if args.empty?
        puts "使い方: #{oparser.program_name} [オプション] <検索文字列> <ファイル or ディレクトリ>..."
        puts "`#{oparser.program_name} --help' でより詳しい情報を表示します。"
        abort
      end

      src = args.shift

      if args.empty?
        args << "."
      end

      Safegrep::Core.run(src, args, options)
    end
  end
end

if $0 == __FILE__
  Safegrep::CLI.execute(ARGV)
end
