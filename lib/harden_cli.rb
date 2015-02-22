# -*- coding: utf-8 -*-
require "optparse"
require_relative "harden_core"

module Harden
  module CLI
    def self.execute(args)
      options = {
        limitsize: 100,
        filemask: ".*",
      }
      oparser = OptionParser.new do |opts|
        opts.version = "2.0.0"
        opts.banner = [
          "テキストファイル連結ツール #{opts.ver}\n\n",
          "使い方: #{opts.program_name} [オプション] ディレクトリ or ファイル...\n\n",
        ].join
        opts.on_head("オプション")
        opts.on
        opts.on("-o", "--output=filename", "出力ファイル") {|v|options[:output] = v }
        opts.on("-s", "--limisize=limitsize", "指定KB以上のファイルは連結しない(初期値#{options[:limitsize]})") {|v|options[:limitsize] = v }
        opts.on("-m", "--filemask=filemask", "指定ファイルのみを連結(初期値/#{options[:filemask]}/)") {|v|options[:filemask] = v }
        opts.on_tail("--help", "このヘルプを表示する") {print opts; exit}
        opts.on_tail(<<-END)

使用例:

    % #{opts.program_name} .               カレントディレクトリ以下のファイルを連結して表示
    % #{opts.program_name} foo bar         fooとbarディレクトリ以下のファイルを連結して表示
    % #{opts.program_name} -m "\\.rb\\z" .   カレントディレクトリ以下の拡張子が .rb のファイルを連結して表示
    % #{opts.program_name} *.rb            カレントディレクトリの拡張子が .rb のファイルを連結して表示
END
      end

      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption => error
        puts error
        exit(1)
      end

      if args.empty?
        puts oparser
        exit(1)
      end

      Harden::Core.run(options.merge(:source => args))
    end
  end
end

if $0 == __FILE__
  Harden::CLI.execute(ARGV)
end
