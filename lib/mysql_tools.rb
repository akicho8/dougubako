# -*- coding: utf-8 -*-
require "bundler/setup"
require "pathname"
require "optparse"
require "pp"

module MysqlTools
  class Core
    def self.run(*args)
      new(*args).command_run
    end

    def initialize(command, args, options)
      @command = command
      @args = args
      @options = options
    end

    def command_run
      public_send @command
    end

    def list
      puts matched_db_list
    end

    def drop
      matched_db_list.each {|db| run_if_x("mysql -u root -e \"DROP DATABASE IF EXISTS #{db}\"") }
    end

    # m table myapp users
    def table
      table_name = @args[0]
      matched_db_list.each {|db| read_run("mysql -u root -e \"show columns from #{table_name}\" #{db}") }
    end

    def create_db
      _create_db(@args[0] || "myapp_development")
    end

    def create_db_all
      db_prefix = @args[0] || "myapp"
      ["production", "development", "test"].each do |env|
        _create_db("#{db_prefix}_#{env}")
      end
    end

    private

    def _create_db(db)
      run_if_x("mysql -u root -e \"DROP DATABASE IF EXISTS #{db}\"")
      run_if_x("mysql -u root -e \"CREATE DATABASE #{db} DEFAULT CHARACTER SET utf8\"")
    end

    def run_if_x(command)
      puts "#{@options[:exec] ? '(run) ' : ''}#{command}"
      if @options[:exec]
        system command
      end
    end

    def read_run(command)
      puts command
      system command
    end

    def matched_db_list
      if str = @args.first
        db_list.find_all{|e|e.include?(str)}
      else
        db_list
      end
    end

    def db_list
      `mysql -u root --raw --batch --skip-column-names -e 'show databases'`.scan(/\S+/) - mysql_system_db_list
    end

    def mysql_system_db_list
      ["information_schema", "mysql", "test"]
    end
  end
end

module MysqlTools
  module CLI
    def self.execute(args)
      options = {}
      oparser = OptionParser.new do |opts|
        opts.banner = [
          "Usage: #{opts.program_name} [options] command...\n\n",
        ].join
        opts.on(<<-EOT)
command:
    list <db>
    drop <db>
    table <db> <table>
    create_db <db>
    create_db_all <db>_(development|production|test)

EOT
        opts.on("オプション:")
        opts.on("-x", "--exec", "本当に実行する") {|v| options[:exec] = v }
        opts.on("--help", "このヘルプを表示する") {puts opts; abort}
        opts.on(<<-EOT)
実行例:
    $ #{opts.program_name} list myapp
    $ #{opts.program_name} drop myapp
    $ #{opts.program_name} table myapp users
    $ #{opts.program_name} create_db myapp_development
    $ #{opts.program_name} create_db_all myapp
EOT
      end

      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption
        puts "オプションが間違っています。"
        puts oparser
        abort
      end

      if args.empty?
        puts oparser
        abort
      end

      MysqlTools::Core.run(args.first, args.drop(1), options)
    end
  end
end

if $0 == __FILE__
  MysqlTools::CLI.execute(ARGV)
end
