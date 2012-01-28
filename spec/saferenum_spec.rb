# -*- coding: utf-8 -*-
require_relative "../spec_helper"
require_relative "../lib/saferenum_cli"

describe do
  before do
    FileUtils.mkdir_p("testdir/a/b")
    open("testdir/a/0000_a1.txt", "w"){}
    open("testdir/a/0000_a2.txt", "w"){}
    open("testdir/a/b/0000_b1.txt", "w"){}
    open("testdir/a/b/0000_b2.txt", "w"){}
  end

  after do
    FileUtils.rm_rf("testdir")
  end

  it "help" do
    `#{LIB_ROOT}/bin/saferenum`.lines.grep(/--help/).size.should == 1
  end

  context "実行結果の確認" do
    before do
      @output = `#{LIB_ROOT}/bin/saferenum -x -r --base=2000 --step=100 testdir`
      # puts @output
    end
    it do
      @output.should match(/ 0000_b2.txt => 02100_b2.txt/)
      @output.should match(/ 0000_a2.txt => 02100_a2.txt/)
    end
  end
end
