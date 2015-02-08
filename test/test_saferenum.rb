# -*- coding: utf-8 -*-
require "test_helper"

class TestSaferenum < Test::Unit::TestCase
  setup do
    FileUtils.mkdir_p("testdir/a/b")
    File.write("testdir/a/0000_a1.txt", "")
    File.write("testdir/a/0000_a2.txt", "")
    File.write("testdir/a/b/0000_b1.txt", "")
    File.write("testdir/a/b/0000_b2.txt", "")
  end

  teardown do
    FileUtils.rm_rf("testdir")
  end

  test "help" do
    assert_equal 1, `#{LIB_ROOT}/bin/saferenum`.lines.grep(/--help/).size
  end

  test "実行結果の確認" do
    @output = `#{LIB_ROOT}/bin/saferenum -x -r --base=2000 --step=100 testdir`
    assert_match %r/ 0000_b2.txt => 02100_b2.txt/, @output
    assert_match %r/ 0000_a2.txt => 02100_a2.txt/, @output
  end
end
