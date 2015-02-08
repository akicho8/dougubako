# -*- coding: utf-8 -*-
require "test_helper"

class TestSaferep < Test::Unit::TestCase
  setup do
    FileUtils.makedirs(Pathname("testdir"))
    File.write("testdir/a.txt", "foo _foo_ FOO")
    File.write("testdir/b.txt", "a($var)a($var)a")
    File.write("testdir/c.txt", "ﾊﾝｶｸとゼンカク")
    File.chmod(0777, "testdir/a.txt")
  end

  teardown do
    FileUtils.rm_rf("testdir")
  end

  test "main" do
    assert_equal 1, `#{LIB_ROOT}/bin/saferep    foo bar testdir`.lines.grep(/→【bar _bar_ FOO】/).size
    assert_equal 1, `#{LIB_ROOT}/bin/saferep -w foo bar testdir`.lines.grep(/→【bar _foo_ FOO】/).size
    assert_equal 1, `#{LIB_ROOT}/bin/saferep    ﾊﾝ xx   testdir`.lines.grep(/→【xxｶｸとゼンカク】/).size
    assert_equal 1, `#{LIB_ROOT}/bin/saferep -u カク xx testdir`.lines.grep(/→【ハンxxとゼンxx】/).size
  end

  test "option_x" do
    assert_equal 1, `#{LIB_ROOT}/bin/saferep -x foo bar testdir`.lines.grep(/→【bar _bar_ FOO】/).size
    assert_equal 1, File.read("testdir/a.txt").lines.grep(/bar _bar_ FOO/).size
    assert_equal 0100777, File.stat("testdir/a.txt").mode, "パーミッションが変化していない"
  end

  test "--activesupport オプションを使うと camelize 等が使える" do
    assert_equal 1, `#{LIB_ROOT}/bin/saferep --activesupport "(_f.o_)" "\#{\\$1.camelize}" testdir`.lines.grep(/→【foo Foo FOO】/).size
  end

  test "block_replace" do
    assert_equal 1, `#{LIB_ROOT}/bin/saferep '_(\\w+)_' '@\#{\$1}@' testdir`.lines.grep(/→【foo @foo@ FOO】/).size
  end

  sub_test_case "エスケープの有無" do
    test "両方エスケープされる" do
      assert `#{LIB_ROOT}/bin/saferep -s  '($var)' 'x\#{$1}x' testdir`.include?('【ax#{$1}xax#{$1}xa】')
    end
    test "置換元だけがエスケープされる" do
      assert `#{LIB_ROOT}/bin/saferep -A '($var)' 'x\#{$1}x' testdir`.include?("【axxaxxa】")
    end
    test "置換後だけがエスケープされる" do
      assert `#{LIB_ROOT}/bin/saferep -B '(\\$var)' 'x\#{$1}x' testdir`.include?("【a(x\#{$1}x)a(x\#{$1}x)a】")
    end
  end
end
