# -*- coding: utf-8 -*-

require "pathname"
require "kconv"

module FileFilter
  extend self

  #
  # 検索・置換対象から外すか？
  #
  def ignore_file?(filepath, options = {})
    filepath = Pathname(filepath).expand_path

    # シンボリックリンクを展開してはいけない。シンボリックリンクを修正するとシン
    # ボリックリンクではなく本当のファイルになってしまう。つまりファイルが複数でき
    # てしまう。
    # filepath = filepath.readlink(filepath) if filepath.symlink?

    # シンボリックリンクならダメ
    if filepath.symlink?
      return true
    end

    # ファイルが無かったらダメ
    unless filepath.exist?
      return true
    end

    # ファイル名にマッチしたらダメ
    list = [
      # 拡張子
      /\.(sqlite3|cache|schemas|old|bak|orig|rej|a|o|Z|elc|ln|rbc|\.del-.*)\z/,
      /\.(pptx|fla|flv|avi||ttf|mp3|mov|mp4|zip|lzh|mpg|jpg|bmp|wav|xm|mid|gif|tar|gz|png|db|swf|svg|diff|xls|ppt|ico|pid|tmp)\z/i,
      # 単語
      /\b(RDEFSX|RDEFS|RCSLOG|RCS|SCCS|TAGS|CHANGELOG|\.make\.sate|\.nse_depinfo|CVS|cvslog|svn|git|log|DS_Store)\b/i,
      /\b(cache|password_dic|coverage|public\/assets)\b/,
      /\b(doc\/app|coverage|pkg|ruby_sess|yardoc)\b/,
      /tmp.*meta_request.*json\z/, # rails tmp/data/meta_request/91f33f2a0bbf97d42fc1b1c95915fc91.json
      /\b(cache|password_dic|coverage|public\/assets)\b/,
      /\.bundle\b/,
      # ゴミ
      "~", "#", "%", "$",
      # その他
      /\b(min)\b.*\.(js|css)\z/,
      /(stylesheets|javascripts|assets)\/_+cache/,
    ]
    if filepath.to_s.match(@file_filter_regexp ||= Regexp.union(*list))
      return true
    end

    # 一つ上がキャッシュディレクトリならダメ
    if filepath.dirname.basename.to_s.match(/cache/i)
      return true
    end

    if filepath.ftype == "directory"
      unless options[:include_directory]
        return true
      end
    end

    # 読めないファイルはダメ
    # ディレクトリは最初から対象外なので強制的にフィルタされる
    if filepath.ftype == "file"
      if !filepath.readable?
        return true
      end
    end

    # 巨大なSQLはダメ
    if filepath.ftype == "file"
      if filepath.extname.match(/sql/i) && filepath.size >= 1024*32
        return true
      end
    end

    # バイナリはダメ
    if filepath.ftype == "file"
      if NKF.guess(filepath.read) == NKF::BINARY
        return true
      end
    end

    false
  end
end
