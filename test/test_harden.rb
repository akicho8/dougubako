# -*- coding: utf-8 -*-
require "test_helper"

class TestHarden < Test::Unit::TestCase
  setup do
    FileUtils.mkdir_p("testdir/a/b")
    open("testdir/a/b/test.html", "w") {|f|f.write("__html__")}
    open("testdir/a/b/test.java", "w") {|f|f.write("__java__")}
    open("testdir/a/b/heavy-ok.txt", "w") {|f|f.write("O" * 1024)}
    open("testdir/a/b/heavy-ng.txt", "w") {|f|f.write("N" * (1024 + 1))}
  end

  teardown do
    FileUtils.rm_rf("testdir")
  end

  test "help" do
    assert_equal 1, `#{LIB_ROOT}/bin/harden --help`.lines.grep(/--filemask/).size
  end

  test "normal" do
    assert_equal 1, `#{LIB_ROOT}/bin/harden testdir`.lines.grep(/__html__/).size
  end

  test "mask" do
    assert_equal 0, `#{LIB_ROOT}/bin/harden -m "\\.java\\z" testdir`.lines.grep(/__html__/).size
    assert_equal 1, `#{LIB_ROOT}/bin/harden -m "\\.java\\z" testdir`.lines.grep(/__java__/).size
  end

  test "test_size" do
    assert_equal 1, `#{LIB_ROOT}/bin/harden -s 1 testdir`.lines.grep(/OOOO/).size
    assert_equal 0, `#{LIB_ROOT}/bin/harden -s 1 testdir`.lines.grep(/NNNN/).size
  end
end
