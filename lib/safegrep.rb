# -*- coding: utf-8 -*-
# 文字列検索ツール

require "optparse"
require_relative 'file_ignore'

module Safegrep
  VERSION = '2.0.4'.freeze

  class Core
    def self.run(*args)
      new(*args).run
    end

    def self.default_options
      {
        :escape   => false,
        :toutf8   => false,
        :word     => false,
        :all      => false,
        :ignocase => false,
        :guess    => false,
      }
    end

    def initialize(source_string, target_files, options = {})
      @source_string = source_string
      @target_files = target_files

      @options = self.class.default_options.merge(options)

      if @options[:toutf8]
        @source_string = @source_string.toutf8
      end

      @log = []
      @error_logs = []
      @counts = Hash.new(0)

      if @options[:escape]
        @source_string = Regexp.quote(@source_string)
      end

      if @options[:word]
        @source_string = "\\b#{@source_string}\\b"
      end

      option = 0
      if @options[:ignocase]
        option |= Regexp::IGNORECASE
      end
      @source_string = Regexp.compile(@source_string, option)

      puts "検索言:【#{@source_string.source}】(大小文字を区別#{@source_string.casefold? ? "しない" : "する"})"
    end

    def run
      @target_files.each do |target_file|
        Pathname(target_file).find do |filename|
          if FileIgnore.ignore?(filename)
            if @options[:debug]
              puts "skip: #{filename}"
            end
            next
          end
          grep_execute(filename)
        end
      end
      result_display
    end

    private

    def grep_execute(filename)
      if @options[:debug]
        puts "process: #{filename}"
      end
      filename = filename.expand_path
      count = 0
      begin
        buffer = filename.read
      rescue Errno::EISDIR => error
        STDERR.puts "警告: #{error}"
      else
        if @options[:toutf8]
          buffer = buffer.toutf8
        end
        buffer.lines.each_with_index do |line, index|
          begin
            if comment_skip?(filename, line)
              next
            end
            line = line.clone
            if line.gsub!(@source_string) {
                count += 1
                "【#{$&}】"
              }
              puts "#{filename}(#{index.succ}): #{line.strip}"
            end
          rescue ArgumentError => error
            @error_logs << "【読み込み失敗】: #{filename} (#{error})"
            break
          end
        end
      end
      if count.nonzero?
        @log << {:filename => filename, :count => count}
      end
      @counts[:total] += count
    end

    def comment_skip?(filename, line)
      if @options[:all]
        return false
      end
      if filename.extname.match(/\b(css|scss)\b/)
        return false
      end
      if filename.extname.match(/\b(el)\b/)
        return line.match(/^\s*;/)
      end
      if filename.extname == ".rb"
        return line.match(/^\s*#/)
      end
      false
    end

    def result_display
      unless @log.empty?
        puts
        puts @log.sort_by{|a|a[:count]}.collect{|e|"#{e[:filename]} (#{e[:count]} hit)"}
      end
      unless @error_logs.empty?
        puts
        puts @error_logs.join("\n")
      end
      puts
      puts "結果: #{@log.size} 個のファイルを対象に #{@counts[:total]} 個所を検索しました。"
    end
  end

  module CLI
    extend self

    def execute(args)
      options = Core.default_options

      oparser = OptionParser.new do |opts|
        opts.version = VERSION
        opts.banner = [
          "文字列検索 #{opts.ver}\n",
          "使い方: #{opts.program_name} [オプション] <検索文字列> <ファイル or ディレクトリ>...\n",
        ].join
        opts.on("オプション")
        opts.on("-i", "--ignore-case", "大小文字を区別しない(#{options[:ignocase]})") {|v| options[:ignocase] = v }
        opts.on("-w", "--word-regexp", "単語とみなす(#{options[:word]})") {|v| options[:word] = v }
        opts.on("-s", "-Q", "検索文字列をエスケープ(#{options[:escape]})") {|v| options[:escape] = v }
        opts.on("-a", "コメント行も含める(#{options[:all]})") {|v| options[:all] = v }
        opts.on("-u", "--[no-]utf8", "半角カナを全角カナに統一(#{options[:toutf8]})") {|v| options[:toutf8] = v }
        opts.on("-d", "--debug", "デバッグモード") {|v| options[:debug] = v }
        opts.on("--help", "このヘルプを表示する") {puts opts; abort}
      end

      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption => error
        puts error
        usage(oparser)
      end

      if args.empty?
        usage(oparser)
      end

      src = args.shift

      if args.empty?
        args << "."
      end

      Safegrep::Core.run(src, args, options)
    end

    def usage(oparser)
      puts "使い方: #{oparser.program_name} [オプション] <検索文字列> <ファイル or ディレクトリ>..."
      puts "`#{oparser.program_name}' --help でより詳しい情報を表示します。"
      abort
    end
  end
end

if $0 == __FILE__
  Safegrep::CLI.execute(ARGV)
end
