# -*- coding: utf-8 -*-
# 動画からサムネイルを生成するツール

require "rubygems"
require "streamio-ffmpeg"
require "optparse"
require "pathname"
require "fileutils"
require "active_support/buffered_logger"

module Safethumb
  class Core
    #
    # ランダムに4個のサムネを生成する
    #
    #   Safethumb::Core.run(["input.flv"], :mode => "random", :count => 4)
    #
    # トータル時間を4分割して4つのサムネを生成する(8秒の動画なら0,2,4,6秒時のサムネになる)
    #
    #   Safethumb::Core.run(["input.flv"], :mode => "div", :count => 4)
    #
    # 0.5秒ずつのサムネを生成する(4秒の動画なら8つのサムネができる)
    #
    #   Safethumb::Core.run(["input.flv"], :mode => "step", :step => 0.5)
    #
    # 0.5秒ずつのサムネを4つ生成する(4秒の動画なら 0, 0.5, 1.0, 1.5 秒時の4つだけ)
    #
    #   Safethumb::Core.run(["input.flv"], :mode => "step", :step => 0.5, :count => 4)
    #
    def self.run(*args, &block)
      new(*args, &block).run
    end

    def self.default_config
      {
        :mode => "div",
        :count => nil,
        :outdir => Pathname.pwd + "_thumbs",
        :extname => "png",
        :convert => "-y -vcodec mjpeg -vframes 1 -an -f rawvideo",
        :exec => true,
        :open => false,
        :step => 1.0,
        :logger => ActiveSupport::BufferedLogger.new("/dev/null"),
      }
    end

    attr_accessor :config

    def initialize(files, config = {}, &block)
      @files = files
      @config = self.class.default_config.merge(config)

      if @config[:logger]
        FFMPEG.logger = @config[:logger]
      end
    end

    def run
      target_files.each do |current_file|
        puts "input: #{current_file}"
        @movie = FFMPEG::Movie.new(current_file.to_s)
        case @config[:mode]
        when "random"
          seeks = (0...@config[:count]).collect{1 + rand(@movie.duration.to_i - 1)}
        when "div"
          step = @movie.duration / @config[:count]
          seeks = generate_seeks(step, @config[:count])
        when "step"
          if @config[:count]
            count = @config[:count]
          else
            count = (@movie.duration / @config[:step]).to_i
          end
          seeks = generate_seeks(@config[:step], count)
        else
          raise "must not happen"
        end

        seeks.each_with_index do |seek, index|
          options = {
            :seek_time => seek,
            :custom => @config[:convert],
          }
          seek_str = seek.to_s.gsub(/\D+/, "_")
          index_str = "%0*d" % [("%d" % seeks.size).size, index.next]
          basename = current_file.basename(".*")
          fname = outdir + ([@config[:prefix], basename.to_s, index_str, seek_str].compact.join("_").to_s + ".#{@config[:extname]}")
          puts "output: [#{index_str}/#{seeks.size}] #{seek} #{fname}"
          if @config[:exec]
            @movie.transcode(fname.to_s, options)
          end
        end
      end
      if @config[:exec]
        if @config[:open] && RUBY_PLATFORM.match(/darwin/)
          `open #{outdir}/#{@config[:prefix]}*`
        end
      end
      unless @config[:exec]
        puts
        puts "本当に置換するには -x オプションを付けてください。"
      end
    end

    def generate_seeks(step, count)
      seeks = (0...count).enum_for(:each_with_index).collect {|value, index| step * index }
      seeks.collect {|v| float_to_time(v) }
    end

    def float_to_time(v)
      s = "%02d:%02d:%02d" % [v.to_i / 60 / 60, v.to_i / 60, v.to_i % 60]
      s + "." + ("%.3f" % (v - v.to_i)).sub("0.", "")
    end

    def target_files
      @files.collect {|file| Pathname(file).expand_path }
    end

    def outdir
      dir = Pathname(@config[:outdir]).expand_path
      unless dir.exist?
        FileUtils.makedirs(dir)
      end
      dir
    end
  end

  module CLI
    def self.execute(args)
      config = Safethumb::Core.default_config.merge({
          :exec => false,
        })

      oparser = OptionParser.new do |opts|
        opts.version = "0.1.0"
        opts.banner = [
          "サムネイル生成スクリプト #{opts.ver}\n\n",
          "使い方: #{opts.program_name} [オプション] files...\n\n",
        ].join
        opts.on_head("オプション:")
        opts.on
        opts.on("-m", "--mode=MODE", "モード(random|div|step)(default: #{config[:mode]})", String) {|v|config[:mode] = v }
        opts.on("-o", "--outdir=DIR", "出力ディレクトリ(default: #{config[:outdir]})", String) {|v|config[:outdir] = v }
        opts.on("-p", "--prefix=PREFIX", "プレフィクス(default: #{config[:prefix]})", String) {|v|config[:prefix] = v }
        opts.on("-c", "--count=COUNT", "生成数(default: #{config[:count]})", Integer) {|v|config[:count] = v }
        opts.on("--ext=EXTNAME", "拡張子(default: #{config[:extname]})", String) {|v|config[:extname] = v }
        opts.on("--convert=ARGS", "ffmpeg引数(default: #{config[:convert]})", String) {|v|config[:convert] = v }
        opts.on("-x", "--[no-]exec", "本当に実行する(default: #{config[:exec]})", TrueClass) {|v|config[:exec] = v }
        opts.on("--open", "実行後の確認(default: #{config[:open]})", TrueClass) {|v|config[:open] = v }
        opts.on("--step=STEP", "stepモードで分割するときのステップ(default: #{config[:step]})", Float) {|v|config[:step] = v }
        opts.on("--clean", "出力ディレクトリを削除するか", TrueClass) {|v|config[:clean] = v }
        opts.on(<<-EOT)

サンプル:

    ■ランダムに4個のサムネを生成する

      $ #{opts.program_name} input.flv --mode=random --count=4

    ■トータル時間を4分割して4つのサムネを生成する(8秒の動画なら0,2,4,6秒時のサムネになる)

      $ #{opts.program_name} input.flv --mode=div --count=4

    ■0.5秒ずつのサムネを生成する(4秒の動画なら8つのサムネができる)

      $ #{opts.program_name} input.flv --mode=step --step=0.5

    ■0.5秒ずつのサムネを4つ生成する(4秒の動画なら 0, 0.5, 1.0, 1.5 秒時の4つだけ)

      $ #{opts.program_name} input.flv --mode=step --step=0.5 --count=4

EOT
      end

      args = oparser.parse(args)
      if args.empty?
        puts oparser
        abort
      end
      Core.run(args, config)
    end
  end
end

if $0 == __FILE__
  # # Safethumb::CLI.execute(ARGV)
  # FileUtils.rm_rf("_thumbs")
  # # Safethumb::CLI.execute(["~/bin/file.flv", "-x", "--open", "--mode", "step", "--step", "2.0"])
  # Safethumb::CLI.execute(["~/bin/file.flv", "-x", "--open", "--mode", "div", "--count", "10"])
  require "active_support/buffered_logger"
  logger = ActiveSupport::BufferedLogger.new(File.expand_path(File.join(File.dirname(__FILE__), "_development.log")))
  # logger = ActiveSupport::BufferedLogger.new("/dev/null")
  # Safethumb::Core.run(["~/bin/file.flv"], :mode => "random", :count => 4, :logger => logger)
  # Safethumb::Core.run(["~/bin/file.flv"], :mode => "random", :count => 4, :logger => logger)
  Safethumb::Core.run(["~/bin/file.flv"], :logger => logger, :mode => "random", :count => 4)
  Safethumb::Core.run(["~/bin/file.flv"], :logger => logger, :mode => "div", :count => 4)
  Safethumb::Core.run(["~/bin/file.flv"], :logger => logger, :mode => "step", :step => 0.5)
  Safethumb::Core.run(["~/bin/file.flv"], :logger => logger, :mode => "step", :step => 0.5, :count => 4)
end
