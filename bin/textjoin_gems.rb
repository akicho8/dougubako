#!/opt/local/bin/ruby -Ku

require "pathname"
require "yaml"
require File.expand_path(File.join(File.dirname(__FILE__), "../lib/textjoin_core"))

module TextJoin
  module Gems
    def self.run
      outputdir = Pathname("/var/textjoin").expand_path
      versions = {}
      all_gems = []
      gem_path = "/opt/local/lib/ruby/gems/1.8"
      Pathname.glob("#{gem_path}/gems/*").each{|path|
        all_gems << path
        if name = path.to_s.slice(/[\w\-]+(?=-\d+\..+\z)/)
          # p [name, path]
          if versions[name]
            # 新しいバージョンの方だけにする
            versions[name] = [versions[name], path.to_s].max
          else
            versions[name] = path.to_s
          end
        else
          puts "skip: #{path} は変な表記なので無視します。"
        end
      }

      # バージョンなし
      print versions.to_yaml
      versions.each{|name, realpath|
        output_filename = "_" + name.gsub("-", "_").downcase
        TextJoin::Core.run(:source => realpath, :output => outputdir.join(output_filename))
      }

      # バージョンあり(_activesupport_2_3_5 みたいなもの)
      all_gems.each{|path|
        output_filename = "_" + path.basename.to_s.gsub(/\W/, "_").downcase
        TextJoin::Core.run(:source => path.to_s, :output => outputdir.join(output_filename))
      }
    end
  end
end

if $0 == __FILE__
  TextJoin::Gems.run
end
