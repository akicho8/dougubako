require "test_helper"

class TestSafefile < Test::Unit::TestCase
  setup do
    FileUtils.mkdir_p("testdir/a/b")
    File.write("testdir/a/file1.txt", "バトルシティー \nルート１６ターボ")
    File.write("testdir/a/file2.txt", ["a", "x", "a", "a"].join("\n"))
    File.write("testdir/a/b/file3.txt", "キン肉マン　マッスルタッグマッチ")
  end

  teardown do
    FileUtils.rm_rf("testdir")
  end

  test "help" do
    assert_equal 1, `#{_bin(:safefile)}`.lines.grep(/--help/).size
  end

  test "実行結果の確認" do
    @output = `#{_bin(:safefile)} -rdu testdir`
    assert_match /\+ キン肉マン マッスルタッグマッチ/, @output
    assert_match /\+ バトルシティー$/, @output
    assert_match /\+ ルート16ターボ$/, @output
    assert_match /\- a$/, @output
  end
end
