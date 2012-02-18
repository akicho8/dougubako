# -*- coding: utf-8 -*-

require_relative "../spec_helper"

describe do
  before do
    FileUtils.makedirs(Pathname("testdir"))
    open("testdir/a.txt", "w") {|f|f.write("foo _foo_ FOO")}
    open("testdir/b.txt", "w") {|f|f.write("a($var)a($var)a")}
    open("testdir/c.txt", "w") {|f|f.write("ﾊﾝｶｸとゼンカク")}
    File.chmod(0777, "testdir/a.txt")
  end

  after do
    FileUtils.rm_rf("testdir")
  end

  it "main" do
    `#{LIB_ROOT}/bin/saferep    foo bar testdir`.lines.grep(/→【bar _bar_ FOO】/).size.should == 1
    `#{LIB_ROOT}/bin/saferep -w foo bar testdir`.lines.grep(/→【bar _foo_ FOO】/).size.should == 1
    `#{LIB_ROOT}/bin/saferep    ﾊﾝ xx   testdir`.lines.grep(/→【xxｶｸとゼンカク】/).size.should == 1
    `#{LIB_ROOT}/bin/saferep -u カク xx testdir`.lines.grep(/→【ハンxxとゼンxx】/).size.should == 1
  end

  it "option_x" do
    `#{LIB_ROOT}/bin/saferep -x foo bar testdir`.lines.grep(/→【bar _bar_ FOO】/).size.should == 1
    File.read("testdir/a.txt").lines.grep(/bar _bar_ FOO/).size.should == 1
    File.stat("testdir/a.txt").mode.should == 0100777 # パーミッションが変化していないか?
  end

  it "block_replace" do
    `#{LIB_ROOT}/bin/saferep '_(\\w+)_' '@\#{\$1}@' testdir`.lines.grep(/→【foo @foo@ FOO】/).size.should == 1
  end

  context "option_s" do
    it "両方エスケープされる" do
      `#{LIB_ROOT}/bin/saferep -s  '($var)' 'x\#{$1}x' testdir`.include?('【ax#{$1}xax#{$1}xa】').should == true
    end
    # # 旧仕様
    # it "置換元だけがエスケープされる" do
    #   `#{LIB_ROOT}/bin/saferep -s1 '($var)' 'x\#{$1}x' testdir`.include?("【axxaxxa】").should == true
    # end
    # it "置換後だけがエスケープされる" do
    #   `#{LIB_ROOT}/bin/saferep -s2 '(\\$var)' 'x\#{$1}x' testdir`.include?("【a(x\#{$1}x)a(x\#{$1}x)a】").should == true
    # end
  end
end
