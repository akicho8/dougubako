# -*- coding: utf-8 -*-
require "test/unit"
require "fileutils"

class TestSimpleGrep < Test::Unit::TestCase
  def setup
    FileUtils.mkdir_p("testdir")
    open("testdir/a.txt", "w") {|f|f.write("foo _foo_ FOO")}
    File.chmod(0777, "testdir/a.txt")
  end

  def teardown
    FileUtils.rm_rf("testdir")
  end

  def test_help
    assert_equal(1, `../bin/sgrep`.lines.grep(/sgrep --help/).size)
    assert_equal(1, `../bin/sgrep --help`.lines.grep(/--ignore/).size)
  end

  def test_main
    assert_equal(1, `../bin/sgrep    foo testdir`.lines.grep(/【foo】 _【foo】_ FOO/).size)
    assert_equal(1, `../bin/sgrep -w foo testdir`.lines.grep(/【foo】 _foo_ FOO/).size)
    assert_equal(1, `../bin/sgrep -i foo testdir`.lines.grep(/【foo】 _【foo】_ 【FOO】/).size)
  end
end
