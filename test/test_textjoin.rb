require "test/unit"
require "fileutils"

class TestRCat < Test::Unit::TestCase
  def setup
    FileUtils.mkdir_p("testdir/a/b")
    open("testdir/a/b/test.html", "w") {|f|f.write("__html__")}
    open("testdir/a/b/test.java", "w") {|f|f.write("__java__")}
    open("testdir/a/b/heavy-ok.txt", "w") {|f|f.write("O" * 1024)}
    open("testdir/a/b/heavy-ng.txt", "w") {|f|f.write("N" * (1024 + 1))}
  end

  def teardown
    FileUtils.rm_rf("testdir")
  end

  def test_help
    assert_equal(1, `../bin/textjoin --help`.grep(/--filemask/).size)
  end

  def test_normal
    assert_equal(1, `../bin/textjoin testdir`.grep(/__html__/).size)
  end

  def test_mask
    assert_equal(0, `../bin/textjoin -m "\\.java\\z" testdir`.grep(/__html__/).size)
    assert_equal(1, `../bin/textjoin -m "\\.java\\z" testdir`.grep(/__java__/).size)
  end

  def test_size
    assert_equal(1, `../bin/textjoin -s 1 testdir`.grep(/OOOO/).size)
    assert_equal(0, `../bin/textjoin -s 1 testdir`.grep(/NNNN/).size)
  end
end
