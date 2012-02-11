# -*- coding: utf-8 -*-
require_relative "../spec_helper"
require_relative "../lib/safefile_cli"

describe do
  before do
    FileUtils.mkdir_p("testdir/a/b")
    open("testdir/a/file1.txt", "w"){|f|f << "バトルシティー \nルート１６ターボ"}
    open("testdir/a/file2.txt", "w"){|f|f << ["a", "x", "a", "a"].join("\n")}
    open("testdir/a/b/file3.txt", "w"){|f|f << "キン肉マン　マッスルタッグマッチ"}
  end

  after do
    FileUtils.rm_rf("testdir")
  end

  it "help" do
    `#{LIB_ROOT}/bin/safefile`.lines.grep(/--help/).size.should == 1
  end

  context "実行結果の確認" do
    before do
      @output = `#{LIB_ROOT}/bin/safefile -rdu testdir`
      # puts @output
    end
    it do
      @output.should match(/\+ キン肉マン マッスルタッグマッチ/)
      @output.should match(/\+ バトルシティー$/)
      @output.should match(/\+ ルート16ターボ$/)
      @output.should match(/\- a$/)
    end
  end
end
