# -*- coding: utf-8 -*-

require "optparse"
require "syslog"
require "pathname"

module Safedaemon
  VERSION = "0.1.0"

  class Core
    def self.run(*args)
      new(*args).run
    end

    def self.default_params
      {
        :interval => 2,
        :daemon   => false,
        :logfile  => "daemon.log",
      }
    end

    def initialize(args, params = {})
      @args = args
      @params = params
    end

    def run
      @count = 0
      _puts "[START]"
      if @params[:daemon]
        _puts "[DAEMON #{Process.pid}]"
        _puts "tail -f /var/log/system.log"
        Process.daemon
      end
      loop do
        _puts [@count, Time.now, @args].inspect
        sleep(@params[:interval])
        @count += 1
      end
      _puts "[EXIT]"
    end

    def _puts(str)
      puts str
      Syslog.open("#{Pathname(__FILE__).basename}", Syslog::LOG_NDELAY)
      Syslog.log(Syslog::LOG_ALERT, "[PID:#{Process.pid}] %s", str)
      Syslog.close
    end
  end

  module CLI
    extend self

    def execute(args)
      params = Core.default_params

      oparser = OptionParser.new do |oparser|
        oparser.version = VERSION
        oparser.banner = [
          "#{oparser.ver}\n",
          "使い方: #{oparser.program_name} [オプション] <検索文字列> <ファイル or ディレクトリ>...\n",
        ].join
        oparser.on("オプション")
        oparser.on("-i", "--interval=SECONDS", "実行間隔(#{params[:interval]})", Integer) {|v|params[:interval] = v}
        oparser.on("-l", "--log=LOGFILE", "ログファイル(#{params[:logfile]})", String) {|v|params[:logfile] = v}
        oparser.on("-d", "デーモン化(#{params[:daemon]})") {|v|params[:daemon] = v}
        oparser.on("--help", "このヘルプを表示する") {puts oparser; abort}
      end

      begin
        args = oparser.parse(args)
      rescue OptionParser::InvalidOption
        puts error
        usage(oparser)
      end

      # if args.empty?
      #   usage(oparser)
      # end

      # src = args.shift
      # 
      # if args.empty?
      #   args << "."
      # end

      Safedaemon::Core.run(args, params)
    end

    def usage(oparser)
      puts "使い方: #{oparser.program_name} [オプション] <検索文字列> <ファイル or ディレクトリ>..."
      puts "`#{oparser.program_name}' --help でより詳しい情報を表示します。"
      abort
    end
  end
end

if $0 == __FILE__
  Safedaemon::CLI.execute(ARGV)
end
