# -*- coding: utf-8 -*-
# 改行統一スクリプト

require "pathname"
require "optparse"
require "jcode"
require "diff/lcs"

require File.expand_path(File.join(File.dirname(__FILE__), "ignore_checker"))

module Safefile
  class Core
    def self.run(*args, &block)
      new(*args, &block).run
    end

    def initialize(files, options = {}, &block)
      @files = files
      @options = {
      }.merge(options)
      if block_given?
        yield self
      end
      @log = []
    end

    def run
      @files.each do |filepath|
        Pathname(filepath).find do |filename|
          if IgnoreChecker.ignore_file?(filename)
            next
          end
          if filename.basename.to_s.match(/(\.min\.|\.(js|css)\z)/)
            next
          end
          if ["development_structure.sql", "schema.rb"].include?(filename.basename.to_s)
            next
          end
          replace(filename)
        end
      end
      puts @log unless @log.empty?
      puts "\n本当に置換するには -x オプションを付けてください。" unless @options[:exec]
    end

    private

    def replace(filename)
      if @options[:sjis]
        medhod = :tosjis
        ret_code = "\r\n"
      else
        medhod = :toutf8
        ret_code = "\n"
      end

      filename = filename.expand_path
      source = filename.read.send(medhod)
      lines = source.split(/\r\n|\r|\n/).collect do |line|
        if @options[:hankaku_space]
          line = line.gsub(/#{[0x3000].pack('U')}/, " ")
        end
        if @options[:to_hankaku]
          line = line.tr("ａ-ｚＡ-Ｚ０-９（）／", "a-zA-Z0-9()/")
        end
        if @options[:raw]
          line = line.gsub(/[\r\n]+$/, "")
        else
          line = line.rstrip
        end
        line
      end

      new_content = lines.join(ret_code)

      # 2行以上の空行を1行にする
      new_content = new_content.gsub(/(#{ret_code}){2,}/, '\1\1')

      # 最後の空行を取る
      new_content = new_content.rstrip + ret_code

      # 改行しかないのなら空にする
      if new_content.match(/\A#{ret_code}\z/)
        new_content = ""
      end

      if @options[:diff]
        diff_display(filename, source, new_content)
      end

      if source != new_content || @options[:force]
        count = Diff::LCS.sdiff(source.lines.to_a, new_content.lines.to_a).count{|diff|diff.action == "!"}
        @log << "update: #{filename} (#{count} diffs)"
        if @options[:exec]
          filename.open("w"){|f|f << new_content}
        end
      end
    end

    def diff_display(filename, old_content, new_content)
      diffs = Diff::LCS.sdiff(old_content.lines.to_a, new_content.lines.to_a)
      diffs.each do |diff|
        if diff.old_element == diff.new_element
        else
          puts "#{filename}:#{diff.old_position.next}: - #{diff.old_element.lstrip}" if diff.old_element
          puts "#{filename}:#{diff.new_position.next}: + #{diff.new_element.lstrip}" if diff.new_element
          puts
        end
      end
    end
  end
end

module Safefile
  module CLI
    def self.execute(args)
      options = {
        :diff => true,
      }

      oparser = OptionParser.new do |oparser|
        oparser.version = "1.0.0"
        oparser.banner = [
          "改行統一 #{oparser.ver}\n\n",
          "使い方: #{oparser.program_name} [オプション] ディレクトリ or ファイル...\n\n",
        ]
        oparser.on_head("オプション")
        oparser.on
        oparser.on("-x", "--exec", "本当に置換する"){|options[:exec]|}
        oparser.on("-f", "--force", "強制置換する"){|options[:force]|}
        oparser.on("-s", "--sjis", "sjisにする。改行もWindows用の CR LF にする"){|options[:sjis]|}
        oparser.on("-r", "--raw", "rstripとかしない"){|options[:raw]|}
        oparser.on("-z", "--hankaku", "全角アルファベットや全角数値や丸かっこを半角にする"){|options[:to_hankaku]|}
        oparser.on("-p", "--hankaku-space", "全角スペースを半角スペースにする"){|options[:hankaku_space]|}
        oparser.on("-d", "--[no]-diff", "diffの表示"){|options[:diff]|}
      end

      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption => error
        puts error
        abort
      end

      if args.empty?
        args << "."
      end

      Safefile::Core.run(args, options)
    end
  end
end

if $0 == __FILE__
  Safefile::CLI.execute(ARGV)
end
