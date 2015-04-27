require "fileutils"
require "pathname"
require "test/unit"

class Test::Unit::TestCase
  def _bin(name)
    Pathname(__dir__).dirname.join("bin/#{name}")
  end
end
