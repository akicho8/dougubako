Dir.chdir(File.expand_path(File.join(File.dirname(__FILE__), "test")))
Dir[File.expand_path(File.join(File.dirname(__FILE__), "test_*.rb"))].each{|filename|load(filename)}
