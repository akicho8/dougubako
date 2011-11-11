# -*- coding: utf-8 -*-
require "pathname"
require "kconv"

module IgnoreChecker
  def self.ignore_file?(filepath, options = {})
    filepath = Pathname(filepath)

    # シンボリックリンクを展開してはいけない。シンボリックリンクを修正するとシン
    # ボリックリンクではなく本当のファイルになってしまう。つまりファイルが複数でき
    # てしまう。
    # filepath = filepath.readlink(filepath) if filepath.symlink?

    if filepath.symlink?
      return true
    end

    unless filepath.exist?
      # puts "Error: #{filepath} は存在しません。"
      return true
    end

    # rails css|js cache
    if filepath.expand_path.to_s.match(/(stylesheets|javascripts)\/_+cache/)
      return true
    end

    # ファイタ対象ファイル
    # RCSLOG RCS SCCS CVS* tags TAGS .make.state .nse_depinfo cvslog.*  *~
    # #* .#* ,* *.old *.bak *.orig *.rej .del-* *.a *.o *.Z *.elc *.ln
    # %%〜%%はSmartyのキャッシュ
    if /\b(RCSLOG|RCS|SCCS|TAGS|CHANGELOG|\.make\.sate|\.nse_depinfo)\b/.match(filepath) ||
        filepath.expand_path.to_s.include?("/tmp/sessions/ruby_sess.") ||
        filepath.expand_path.to_s.match(/\b(cache|password_dic|coverage|public\/assets)\b/) ||
        /(CVS.*|cvslog\.*)/.match(filepath) ||
        /\.(svn|git)\b/.match(filepath) ||
        /~\z/.match(filepath.basename) ||
        /^.?#/.match(filepath.basename) ||
        /^%%.*%%/.match(filepath.basename) ||
        /\.(cache|schemas|old|bak|orig|rej|a|o|Z|elc|ln|rbc|\.del-.*)\z/.match(filepath) ||
        /\.log(\.|\z)/.match(filepath) ||
        /\.min\.(js|css)\z/.match(filepath) ||
        %r!\bdoc/app\b!.match(filepath) || # rails RAILS_ROOT/doc/app
        %r!\btmp/coverage\b!.match(filepath) || # rails RAILS_ROOT/tmp/coverage
        %r!\bpkg\b!.match(filepath) || # rails RAILS_ROOT/pkg
        /\.(fla|flv|avi||ttf|mp3|mov|mp4|zip|lzh|mpg|jpg|bmp|wav|xm|mid|gif|tar|gz|png|db|swf|svg|diff|xls|ppt|ico|pid|tmp)\z/.match(filepath)
      return true
    end

    # 一つ上がキャッシュディレクトリなら無視する
    if filepath.dirname.basename.to_s.match(/cache/i)
      return true
    end

    if filepath.ftype == "directory"
      unless options[:include_directory]
        return true
      end
    end

    if filepath.ftype == "file"
      # ディレクトリは最初から対象外なので強制的にフィルタされる
      # 読めないファイルも対象外になる。
      if !filepath.readable?
        return true
      end
    end

    # 巨大なSQLを除く
    if filepath.ftype == "file"
      if filepath.extname.match(/sql/i) && filepath.size >= 1024*32
        return true
      end
    end

    # バイナリを省く
    if filepath.ftype == "file"
      if NKF.guess(filepath.read) == NKF::BINARY
        return true
      end
    end

    false
  end
end
