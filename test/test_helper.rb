require "fileutils"
require "pathname"
require "test/unit"

# $LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

class Test::Unit::TestCase
  LIB_ROOT = Pathname(__FILE__).dirname.dirname
end
