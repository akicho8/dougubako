#!/opt/local/bin/ruby -Ku
# -*- coding: utf-8; compile-command: "./saferenum_cli.rb ~/Pictures/日常" -*-
# ファイルを連番にリネームするスクリプト

require "optparse"
require File.expand_path(File.join(File.dirname(__FILE__), "ignore_checker"))

module Saferenum
  class Core
    def self.run(*args, &block)
      new(*args, &block).run
    end

    def initialize(target_dirs, options)
      @target_dirs = target_dirs
      @options = options
      @log = []
    end

    def run
      @target_dirs.each{|target_dir|
        run_directory(target_dir)
      }
      result_display
    end

    def run_directory(directory)
      # まずは . で始まるのを消して必要なものだけに絞る
      entries = directory.entries.reject{|entry|entry.to_s.match(/\A\./)}.sort

      # そのままだと directory? が使えなかったりと扱いにくいので絶対パスにする
      entries = entries.collect{|entry|directory + entry}

      # カレントのファイルたち
      target_files = entries.find_all{|entry|!entry.directory?}

      # サブディレクトリ
      sub_dirs = entries.find_all{|entry|entry.directory? && !entry.basename.to_s.match(/\A(cvs|rcs)\z/i)}

      # サブディレクトリを先に処理する
      sub_dirs.each{|sub_dir|
        run_directory(sub_dir)
      }

      # 元のファイル名と被らないように元のファイル名を集める
      ignore_names = target_files.collect{|target_file|target_file.basename(".*").to_s}

      # 変更後のファイル名の生成、既存のものと、生成後のものと、被らないようにする
      rename_infos = target_files.enum_with_index.collect{|target_file, index|
        basename = nil
        loop {
          index = index.next
          basename = "#{@options[:prefix]}#{@options[:format]}" % index
          unless ignore_names.include?(basename)
            ignore_names << basename # 重要
            break
          end
        }
        filename = target_file.dirname + "#{basename}#{target_file.extname.downcase}"
        {:target_file => target_file, :new_filename => filename}
      }

      # 変換後とファイル名が同じなら省く
      rename_infos = rename_infos.reject{|rename_info|
        resut = (rename_info[:target_file].basename == rename_info[:new_filename].basename)
        if resut
          puts "skip: #{rename_info[:target_file]}"
        end
        resut
      }

      # 変換後のファイルがあれば止める
      if false
        rename_infos.each{|rename_info|
          if rename_info[:new_filename].exist?
            puts "ファイルがすでに存在しています : #{rename_info[:target_file]} => #{rename_info[:new_filename]}"
            exit 1
          end
        }
      end

      # 変換
      rename_infos.each{|rename_info|
        result = ""
        begin
          ret = 0
          if rename_info[:new_filename].exist?
            puts "すでにあるのでリネーム直前でスキップ: #{rename_info[:target_file]} => #{rename_info[:new_filename]}"
          else
            if @options[:exec]
              ret = rename_info[:target_file].rename(rename_info[:new_filename])
            end
          end
          if ret == 0
            result = "ok"
          else
            result = "error"
          end
        rescue => error
          result = error.message
        end
        puts "#{rename_info[:target_file]}:【#{rename_info[:new_filename].basename('.*')}】 #{result}".strip
      }
    end

    def result_display
      unless @log.empty?
        puts @log.join("\n")
      end
      puts "\n本当に実行するには -x オプションを付けてください。" unless @options[:exec]
    end
  end

  module CLI
    def self.execute(args)
      options = {
        :prefix => "",
        :format => "%04d",
        :recursive => false,
      }

      oparser = OptionParser.new do |oparser|
        oparser.version = "1.0.0"
        oparser.banner = [
          "ファイルを連番にリネームするスクリプト #{oparser.ver}\n\n",
          "使い方: #{oparser.program_name} [オプション] [オプション] 対象ディレクトリ...\n\n",
        ]
        oparser.on_head("オプション")
        oparser.on
        oparser.on("-x", "--exec", "実際に実行する") {|options[:exec]|}
        oparser.on("-r", "--recursive", "サブディレクトリも対象にする(デフォルト:#{options[:recursive]})") {|options[:recursive]|}
        oparser.on("-f", "--format=STRING", "フォーマット(デフォルト:#{options[:format].dump})") {|options[:format]|}
        oparser.on("-p", "--prefix=STRING", "接頭語(デフォルト:#{options[:prefix].dump})") {|options[:prefix]|}
        oparser.on_tail("-h", "--help", "このヘルプを表示する") {print opts; exit}
      end

      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption
        puts "オプションが間違っています。"
        abort
      end

      def usage
        print ARGV.options
        exit
      end

      if ARGV.empty?
        print ARGV.options
        exit
      end

      # ARGV << "." if ARGV.empty?

      target_dirs = ARGV.collect{|target_pathname|Pathname.new(target_pathname).expand_path}
      Saferenum::Core.run(target_dirs, options)
    end
  end
end

if $0 == __FILE__
  Saferenum::CLI.execute(ARGV)
end
