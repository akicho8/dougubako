# -*- coding: utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__), "ignore_checker"))

module SimpleGrep
  class Core
    def self.run(*args)
      new(*args).run
    end

    def initialize(source_string, target_files, options = {})
      @source_string = source_string
      @target_files = target_files

      @options = {
        :print => true,
      }.merge(options)

      @source_string = @source_string.toutf8

      @log = []
      @total_count = 0

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

      if @options[:print]
        puts "検索情報:【#{@source_string.source}】(大小文字を区別#{@source_string.casefold? ? "しない" : "する"})"
      end
    end

    def run
      @target_files.each do |target_file|
        Pathname(target_file).find do |filename|
          next if IgnoreChecker.ignore_file?(filename)
          grep_execute(filename)
        end
      end
      result_display
    end

    private

    def grep_execute(filename)
      filename = filename.expand_path
      count = 0
      begin
        buffer = filename.read
      rescue Errno::EISDIR => error
        STDERR.puts "警告: #{error}"
      else
        css_flag = filename.extname.match(/\.(css|scss)\z/)
        buffer.toutf8.each_with_index do |line, index|
          if !css_flag && !@options[:no_comment_skip]
            if line.match(/^\s*#/)
              next
            end
          end
          line = line.clone
          if line.gsub!(@source_string){count += 1; "【#{$&}】"}
            if @options[:print]
              puts "#{filename}(#{index.succ}): #{line.strip}"
            end
          end
        end
      end
      if count.nonzero?
        @log << {:filename => filename, :count => count}
      end
      @total_count += count
    end

    def result_display
      unless @log.empty?
        puts
        puts @log.sort_by{|a|a[:count]}.collect{|e|"#{e[:filename]}: (#{e[:count]} hit)"}
        puts
      end
      puts "結果: #{@log.size} 個のファイルを対象に #{@total_count} 個所を検索しました。"
    end
  end
end
