# -*- coding: utf-8 -*-
# ファイル and ディレクトリ名置換

require 'optparse'
require_relative 'file_ignore'

module Saferen
  VERSION = "2.0.1"

  class Core
    def self.run(*args, &block)
      new(*args, &block).run
    end

    def initialize(source_regexp, dest_text, files, **options)
      @source_regexp = source_regexp
      @dest_text = dest_text
      @files = files
      @options = options
      @log = []
      @replace_count = 0
      @backup_dir = Pathname.new("~/tmp").expand_path
      @counts = Hash.new(0)

      option = 0
      if @options[:ignocase]
        option |= Regexp::IGNORECASE
      end
      if @options[:word]
        @source_regexp = "\\b#{@source_regexp}\\b"
      end
      @source_regexp = Regexp.compile(@source_regexp, option)
      puts "置換情報:【#{@source_regexp.source}】=>【#{@dest_text}】(大小文字を区別#{@source_regexp.casefold? ? "しない" : "する"})"

      @targets = []

      @files.each do |file|
        file = Pathname(file).expand_path
        file.find do |f|
          if f.to_s.match(/(\.(svn|git)|\b(cvs)|\b(rcs))\b/i)
            next
          end
          @targets << f
        end
      end

      @targets.uniq!
    end

    def run
      # file
      @target_files = @targets.find_all(&:file?)
      execute(@target_files)

      # directory
      @target_dirs = @targets.find_all(&:directory?)
      @target_dirs = @target_dirs.sort_by{|v|v.to_s.count(File::SEPARATOR)}.reverse
      execute(@target_dirs)

      result_display
    end

    def execute(files)
      files.each do |fname|
        original_basename = fname.basename.to_s

        original_basename = original_basename.toutf8
        new_basename = original_basename.clone
        new_basename = new_basename.gsub(@source_regexp) {
          # @dest_textには $1 などが含まれるので外に出してはいけない。
          eval(%("#{@dest_text}"))
        }
        if original_basename != new_basename
          @replace_count += 1
          result = ""
          begin
            new_fname = fname.dirname + new_basename
            ret = 0
            # p new_fname
            if new_fname.exist?
              puts "CollisionError: #{new_fname}"
              @counts[:collision] += 1
            end
            if @options[:exec]
              new_fname.dirname.mkpath
              # ret = fname.rename(new_fname)
            end
            if ret == 0
              result = "成功"
            else
              result = "失敗"
            end
          rescue => error
            result = error.inspect
          end
          puts "#{fname}:【#{original_basename.strip}】→【#{new_basename.strip}】 #{result}".strip
        end
      end
    end

    def result_display
      unless @log.empty?
        puts @log
      end
      puts "重複: #{@counts[:collision]} 個"
      puts "#{@replace_count} 個所を置換しました。"
      unless @options[:exec]
        puts "本当に置換するには -x オプションを付けてください。"
      end
    end
  end

  module CLI
    def self.execute(args)
      options = {}

      oparser = OptionParser.new do |o|
        o.version = VERSION
        o.banner = [
          "ファイル・デイレクトリ名置換 #{o.ver}\n",
          "使い方: #{o.program_name} [オプション] <置換元> <置換後> <ファイル or ディレクトリ>...\n",
        ].join
        o.on_head("オプション:")
        o.on("-x", "--exec", "実際に置換する") {|v| options[:exec] = v }
        o.on("-i", "--ignore-case", "大小文字を区別しない") {|v| options[:ignocase] = v }
        o.on("-w", "--word-regexp", "単語とみなす") {|v| options[:word] = v }
      end

      begin
        args = oparser.parse(args)
      rescue OptionParser::InvalidOption
        puts "オプションが間違っています。"
        abort
      end

      source_regexp = args.shift
      dest_text = args.shift
      if source_regexp.nil? || dest_text.nil?
        puts "使い方: #{oparser.program_name} [オプション] <置換元> <置換後> <ファイル or ディレクトリ>..."
        puts "`#{oparser.program_name} --help' でより詳しい情報を表示します。"
        abort
      end

      if args.empty?
        args << "."
      end

      Core.run(source_regexp, dest_text, args, options)
    end
  end
end

if $0 == __FILE__
  Saferen::CLI.execute(["0011", "00xx", "~/src/myapp/public/master_images/quest_area"])
  # Saferen::CLI.execute(ARGV)
end
