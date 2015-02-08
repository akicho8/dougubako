# -*- coding: utf-8 -*-
require "test_helper"

class TestSafefile < Test::Unit::TestCase
  setup do
    FileUtils.mkdir_p("testdir/a/b")
    open("testdir/a/file1.txt", "w"){|f|f << "バトルシティー \nルート１６ターボ"}
    open("testdir/a/file2.txt", "w"){|f|f << ["a", "x", "a", "a"].join("\n")}
    open("testdir/a/b/file3.txt", "w"){|f|f << "キン肉マン　マッスルタッグマッチ"}
  end

  teardown do
    FileUtils.rm_rf("testdir")
  end

  test "help" do
    assert_equal 1, `#{LIB_ROOT}/bin/safefile`.lines.grep(/--help/).size
  end

  test "実行結果の確認" do
    @output = `#{LIB_ROOT}/bin/safefile -rdu testdir`
    assert_match /\+ キン肉マン マッスルタッグマッチ/, @output
    assert_match /\+ バトルシティー$/, @output
    assert_match /\+ ルート16ターボ$/, @output
    assert_match /\- a$/, @output
  end
end
