require "test_helper"

class TestHarden < Test::Unit::TestCase
  setup do
    FileUtils.mkdir_p("testdir/a/b")
    File.write("testdir/a/b/test.html", "__html__")
    File.write("testdir/a/b/test.java", "__java__")
    File.write("testdir/a/b/heavy-ok.txt", "O" * 1024)
    File.write("testdir/a/b/heavy-ng.txt", "N" * (1024 + 1))
  end

  teardown do
    FileUtils.rm_rf("testdir")
  end

  test "help" do
    assert_equal 1, `#{_bin(:harden)} --help`.lines.grep(/--filemask/).size
  end

  test "normal" do
    assert_equal 1, `#{_bin(:harden)} testdir`.lines.grep(/__html__/).size
  end

  test "mask" do
    assert_equal 0, `#{_bin(:harden)} -m "\\.java\\z" testdir`.lines.grep(/__html__/).size
    assert_equal 1, `#{_bin(:harden)} -m "\\.java\\z" testdir`.lines.grep(/__java__/).size
  end

  test "test_size" do
    assert_equal 1, `#{_bin(:harden)} -s 1 testdir`.lines.grep(/OOOO/).size
    assert_equal 0, `#{_bin(:harden)} -s 1 testdir`.lines.grep(/NNNN/).size
  end
end
