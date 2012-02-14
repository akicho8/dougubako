# -*- coding: utf-8 -*-

require_relative "../spec_helper"

describe do
  before do
    FileUtils.mkdir_p("testdir")
    open("testdir/a.txt", "w") {|f|f.write("foo _foo_ FOO")}
    open("testdir/b.txt", "w") {|f|f.write("ﾊﾝｶｸ ゼンカク")}
    File.chmod(0777, "testdir/a.txt")
  end

  after do
    FileUtils.rm_rf("testdir")
  end

  it "help" do
    `#{LIB_ROOT}/bin/sgrep`.lines.grep(/--help/).size.should == 1
    `#{LIB_ROOT}/bin/sgrep --help`.lines.grep(/--ignore/).size.should == 1
  end

  it "main" do
    `#{LIB_ROOT}/bin/sgrep    foo testdir`.lines.grep(/【foo】 _【foo】_ FOO/).size.should == 1
    `#{LIB_ROOT}/bin/sgrep -w foo testdir`.lines.grep(/【foo】 _foo_ FOO/).size.should == 1
    `#{LIB_ROOT}/bin/sgrep -i foo testdir`.lines.grep(/【foo】 _【foo】_ 【FOO】/).size.should == 1
    `#{LIB_ROOT}/bin/sgrep    ｶｸ  testdir`.lines.grep(/ﾊﾝ【ｶｸ】 ゼンカク/).size.should == 1
    `#{LIB_ROOT}/bin/sgrep -u ｶｸ  testdir`.lines.grep(/ハン【カク】 ゼン【カク】/).size.should == 1
  end
end
