# -*- coding: utf-8 -*-
require "optparse"
require_relative 'harden_core'

module Harden
  module CLI
    def self.execute(args)
      params = {}

      # オプション初期値
      params[:limitsize] = 100
      params[:filemask] = ".*"

      oparser = OptionParser.new do |oparser|
        oparser.version = "2.0.0"
        oparser.banner = [
          "テキストファイル連結ツール #{oparser.ver}\n\n",
          "使い方: #{oparser.program_name} [オプション] ディレクトリ or ファイル...\n\n",
        ].join
        oparser.on_head("オプション")
        oparser.on
        oparser.on("-o", "--output=filename", "出力ファイル") {|v|params[:output] = v }
        oparser.on("-s", "--limisize=limitsize", "指定KB以上のファイルは連結しない(初期値#{params[:limitsize]})") {|v|params[:limitsize] = v }
        oparser.on("-m", "--filemask=filemask", "指定ファイルのみを連結(初期値/#{params[:filemask]}/)") {|v|params[:filemask] = v }
        oparser.on_tail("--help", "このヘルプを表示する") {print oparser; exit}
        oparser.on_tail(<<-END)

使用例:

    % #{oparser.program_name} .               カレントディレクトリ以下のファイルを連結して表示
    % #{oparser.program_name} foo bar         fooとbarディレクトリ以下のファイルを連結して表示
    % #{oparser.program_name} -m "\\.rb\\z" .   カレントディレクトリ以下の拡張子が .rb のファイルを連結して表示
    % #{oparser.program_name} *.rb            カレントディレクトリの拡張子が .rb のファイルを連結して表示
END

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

        Harden::Core.run(params.merge(:source => args))
      end
    end
  end
end

if $0 == __FILE__
  Harden::CLI.execute(ARGV)
end
