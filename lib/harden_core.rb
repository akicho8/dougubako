# -*- coding: utf-8 -*-
require "pathname"
require "stringio"
require "fileutils"

require_relative 'file_ignore'

module TextJoin
  class Core
    def self.run(*args)
      new(*args).run
    end

    def initialize(params = {})
      @params = {
        :limitsize => nil,
        :filemask => nil,
      }.merge(params)

      @src_files = []
      @filter_files = []
      @heavy_files = []
    end

    def run
      all_files
      str = parse_as_string

      if @params[:output]
        output = Pathname(@params[:output]).expand_path
        FileUtils.makedirs(output.dirname)
        output.open("w"){|f|f << str}
        puts "write: #{output} (size: #{str.size}) (soruce: #{target_dirs.join(', ')})"
      else
        puts str
      end
    end

    private

    # ファイルやディレクトリの登録
    def all_files
      target_dirs.each do |target_dir|
        Pathname.glob("#{target_dir}/**/*") do |filename|
          if FileIgnore.ignore?(filename)
            @filter_files << filename
            next
          end

          # ファイルサイズチェック
          if @params[:limitsize]
            if filename.size > @params[:limitsize].to_i * 1024
              @heavy_files << filename
              next
            end
          end

          # ファイルマスク
          if @params[:filemask]
            unless /#{@params[:filemask]}/.match(filename.to_s)
              @filter_files << filename
              next
            end
          end

          @src_files << filename
        end
      end
      @src_files.sort!
    end

    # 結果取得
    def parse_as_string
      o = StringIO.new
      o << header
      o << ""
      o << body
      o.string
    end

    # ヘッダ取得(フィルタ後でなければならない)
    def header
      o = StringIO.new
      o.puts "-*- mode: outline; coding: utf-8-unix; -*-"
      o.puts ""
      o.puts "このファイルは #{File.expand_path($0)} により #{Time::new.strftime("%Y/%m/%d %T")} に自動生成されました。"
      o.puts "ファイルサイズ制限は #{@params[:limitsize]}KB です。" if @params[:limitsize]
      o.puts "ファイルマスクは /#{@params[:filemask]}/ です。" if @params[:filemask]
      o.puts ""
      o.puts "* ファイルリスト"
      o.puts ""
      @src_files.each_with_index {|filename, i|
        o.puts sub_header(i, filename)
      }
      o.puts ""
      o.puts "* ディレクトリリスト"
      o.puts ""
      @src_files.collect{|e|e.dirname}.uniq.each_with_index {|e, i|
        o.puts "####DIR%04d: %s" % [i.succ, e]
      }
      if false
        if @filter_files.size >= 1
          o.puts ""
          o.puts "* 除外したファイル"
          o.puts ""
          @filter_files.each_with_index {|e, i|
            o.puts "%4d %s" % [i.succ, e]
          }
        end
      end
      if @heavy_files.size >= 1
        o.puts ""
        o.puts "* サイズが大きすぎてフィルタされたファイル"
        o.puts ""
        @heavy_files.each_with_index{|e, i|
          o.puts "%4d %s" % [i.succ, e]
        }
      end
      o.string
    end

    # ファイル用のヘッダ
    def sub_header(i, filename)
      "####FILE%04d: %s" % [i.succ, filename]
    end

    # ファイル連結部分
    def body
      o = StringIO.new
      @src_files.each_with_index{|filename, i|
        o.puts "-" * 80
        o.puts "* #{sub_header(i, filename)}"
        o.puts "-" * 80
        NKF::nkf("--unix", filename.read).lines.each{|line|
          o.puts line.toutf8.rstrip
        }
      }
      o.string
    end

    def target_dirs
      [@params[:source]].flatten.collect{|e|Pathname(e).expand_path}.uniq
    end
  end
end

if $0 == __FILE__
  TextJoin::Core.new(:source => "~/bin", :output => "/tmp/a.txt").run
end
