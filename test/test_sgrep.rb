require "test_helper"

class TestSgrep < Test::Unit::TestCase
  setup do
    FileUtils.mkdir_p("testdir")
    File.write("testdir/a.txt", "foo _foo_ FOO")
    File.write("testdir/b.txt", "ﾊﾝｶｸ ゼンカク")
    File.chmod(0777, "testdir/a.txt")
  end

  teardown do
    FileUtils.rm_rf("testdir")
  end

  test "help" do
    assert_equal 1, `#{_bin(:sgrep)}`.lines.grep(/--help/).size
    assert_equal 1, `#{_bin(:sgrep)} --help`.lines.grep(/--ignore/).size
  end

  test "main" do
    assert_equal 1, `#{_bin(:sgrep)}    foo testdir`.lines.grep(/【foo】 _【foo】_ FOO/).size
    assert_equal 1, `#{_bin(:sgrep)} -w foo testdir`.lines.grep(/【foo】 _foo_ FOO/).size
    assert_equal 1, `#{_bin(:sgrep)} -i foo testdir`.lines.grep(/【foo】 _【foo】_ 【FOO】/).size
    assert_equal 1, `#{_bin(:sgrep)}    ｶｸ  testdir`.lines.grep(/ﾊﾝ【ｶｸ】 ゼンカク/).size
    assert_equal 1, `#{_bin(:sgrep)} -u ｶｸ  testdir`.lines.grep(/ハン【カク】 ゼン【カク】/).size
  end
end
