require_relative "../spec_helper"

describe do
  before do
    FileUtils.mkdir_p("testdir/a/b")
    open("testdir/a/b/test.html", "w") {|f|f.write("__html__")}
    open("testdir/a/b/test.java", "w") {|f|f.write("__java__")}
    open("testdir/a/b/heavy-ok.txt", "w") {|f|f.write("O" * 1024)}
    open("testdir/a/b/heavy-ng.txt", "w") {|f|f.write("N" * (1024 + 1))}
  end

  after do
    FileUtils.rm_rf("testdir")
  end

  it "help" do
    `#{LIB_ROOT}/bin/textjoin --help`.lines.grep(/--filemask/).size.should == 1
  end

  it "normal" do
    `#{LIB_ROOT}/bin/textjoin testdir`.lines.grep(/__html__/).size.should == 1
  end

  it "mask" do
    `#{LIB_ROOT}/bin/textjoin -m "\\.java\\z" testdir`.lines.grep(/__html__/).size.should == 0
    `#{LIB_ROOT}/bin/textjoin -m "\\.java\\z" testdir`.lines.grep(/__java__/).size.should == 1
  end

  it "test_size" do
    `#{LIB_ROOT}/bin/textjoin -s 1 testdir`.lines.grep(/OOOO/).size.should == 1
    `#{LIB_ROOT}/bin/textjoin -s 1 testdir`.lines.grep(/NNNN/).size.should == 0
  end
end
