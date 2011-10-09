require "test/unit"
require "fileutils"
require "pathname"

class TestReplace < Test::Unit::TestCase
  def setup
    FileUtils.makedirs(Pathname("testdir"))
    open("testdir/a.txt", "w") {|f|f.write("foo _foo_ FOO")}
    open("testdir/b.txt", "w") {|f|f.write("a($var)a($var)a")}
    File.chmod(0777, "testdir/a.txt")
  end

  def teardown
    FileUtils.rm_rf("testdir")
  end

  def test_help
    # assert_equal(1, `../bin/saferep`.grep(/saferep --help/).size)
    # assert_equal(1, `../bin/saferep --help`.grep(/--exec/).size)
  end

  def test_main
    assert_equal(1, `../bin/saferep    foo bar testdir`.grep(/→【bar _bar_ FOO】/).size)
    assert_equal(1, `../bin/saferep -w foo bar testdir`.grep(/→【bar _foo_ FOO】/).size)
    assert_equal(1, `../bin/saferep -i foo bar testdir`.grep(/→【bar _bar_ bar】/).size)
  end

  def test_option_x
    assert_equal(1, `../bin/saferep -x foo bar testdir`.grep(/→【bar _bar_ FOO】/).size)
    assert_equal(1, File.read("testdir/a.txt").grep(/bar _bar_ FOO/).size)
    assert_equal(0100777, File.stat("testdir/a.txt").mode) # パーミッションが変化していないか?
  end

  def test_block_replace
    assert_equal(1, `../bin/saferep '_(\\w+)_' '@\#{\$1}@' testdir`.grep(/→【foo @foo@ FOO】/).size)
  end

  def test_option_s
    assert_match("ax\#{$1}xax\#{$1}xa", `../bin/saferep     -s  '($var)' 'x\#{$1}x' testdir`) # 両方エスケープされる
    assert_match("axxaxxa", `../bin/saferep                 -s1 '($var)' 'x\#{$1}x' testdir`) # 置換元だけがエスケープされる
    assert_match("a(x\#{$1}x)a(x\#{$1}x)a", `../bin/saferep -s2 '(\\$var)' 'x\#{$1}x' testdir`) # 置換後だけがエスケープされる
  end
end
