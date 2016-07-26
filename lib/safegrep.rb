# -*- coding: utf-8 -*-
# 文字列検索ツール

require "optparse"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/string/filters"
require_relative 'file_ignore'

module Safegrep
  VERSION = '2.0.5'

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
        :fuzzy    => false,
      }
    end

    def initialize(str, files, options = {})
      @str = str
      @files = files
      @options = self.class.default_options.merge(options)

      if @options[:toutf8]
        @str = @str.toutf8
      end

      @log = []
      @errors = []
      @counts = Hash.new(0)

      if @options[:escape]
        @str = Regexp.quote(@str)
      end

      if @options[:word]
        @str = "\\b#{@str}\\b"
      end

      if @options[:fuzzy]
        @str = @str.sub(/_?info\z/i, '')
        @str = @str.sub(/keys?_types?\z/i, '')
        @str = @str.sub(/types?_keys?\z/i, '')
        @str = @str.sub(/(key|type)s?\z/i, '')
        @str = @str.sub(/\A_*(.*?)_*\z/i, '\1')

        @str = Regexp.union(*[
            /#{@str}/i,
            /#{@str.underscore}/i,
            /#{@str.camelize}/i,
          ])
      end

      option = 0
      if @options[:ignocase]
        option |= Regexp::IGNORECASE
      end
      @str = Regexp.compile(@str, option)

      puts "検索言:【#{@str.source}】(大小文字を区別#{@str.casefold? ? "しない" : "する"})"
    end

    def run
      @files.each do |e|
        Pathname(e).find do |file|
          if FileIgnore.ignore?(file)
            if @options[:debug]
              puts "skip: #{file}"
            end
            next
          end
          file_read(file)
        end
      end
      result_display
    end

    private

    def file_read(file)
      file = file.expand_path
      if @options[:debug]
        puts "read: #{file}"
      end
      count = 0
      begin
        buffer = file.read
      rescue Errno::EISDIR => error
        STDERR.puts "警告: #{error}"
      else
        if @options[:toutf8]
          buffer = buffer.toutf8
        end
        buffer.lines.each_with_index do |line, i|
          begin
            if comment_skip?(file, line)
              next
            end
            line = line.clone
            if line.gsub!(@str) {
                count += 1
                "【#{$&}】"
              }
              s = line.squish
              if file.to_s.match(/\.json\z/)
                s = s.truncate(256)
              end
              puts "#{file}(#{i.next}): #{s}"
            end
          rescue ArgumentError => error
            @errors << "【読み込み失敗】: #{file} (#{error})"
            break
          end
        end
      end
      if count.nonzero?
        @log << {:file => file, :count => count}
      end
      @counts[:total] += count
    end

    def comment_skip?(file, line)
      if @options[:all]
        return false
      end
      if file.extname.match(/\b(css|scss)\b/)
        return false
      end
      if file.extname.match(/\b(el)\b/)
        return line.match(/^\s*;/)
      end
      if file.extname == ".rb"
        return line.match(/^\s*#/)
      end
      false
    end

    def result_display
      unless @log.empty?
        puts
        puts @log.sort_by{|a|a[:count]}.collect { |e| "#{e[:file]} (#{e[:count]} hit)" }
      end
      unless @errors.empty?
        puts
        puts @errors.join("\n")
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
        opts.on("-i", "--ignore-case", "大小文字を区別しない(#{options[:ignocase]})") {|v| options[:ignocase] = v  }
        opts.on("-w", "--word-regexp", "単語とみなす(#{options[:word]})")             {|v| options[:word] = v      }
        opts.on("-f", "--fuzzy", "曖昧検索(#{options[:fuzzy]})")                      {|v| options[:fuzzy] = v     }
        opts.on("-s", "-Q", "検索文字列をエスケープ(#{options[:escape]})")            {|v| options[:escape] = v    }
        opts.on("-a", "コメント行も含める(#{options[:all]})")                         {|v| options[:all] = v       }
        opts.on("-u", "--[no-]utf8", "半角カナを全角カナに統一(#{options[:toutf8]})") {|v| options[:toutf8] = v    }
        opts.on("-d", "--debug", "デバッグモード")                                    {|v| options[:debug] = v     }
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

      Core.run(src, args, options)
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
