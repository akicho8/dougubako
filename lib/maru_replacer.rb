class MaruReplacer
  def replace(str)
    str.gsub(/[#{replace_hash.keys.join}]/o, replace_hash)
  end

  def list
    [
      {:shape => "○", :size => "中", :base => 0,  :range => 0x24ea..0x24ea   },
      {:shape => "○", :size => "中", :base => 1,  :range => 0x2460..0x2473   },
      {:shape => "○", :size => "中", :base => 21, :range => 0x3251..0x325f   },
      {:shape => "○", :size => "中", :base => 36, :range => 0x32b1..0x32bf   },
      {:shape => "○", :size => "小", :base => 0,  :range => 0x1f10b..0x1f10b },
      {:shape => "○", :size => "小", :base => 1,  :range => 0x2780..0x2789   },
      {:shape => "●", :size => "中", :base => 0,  :range => 0x24ff..0x24ff   },
      {:shape => "●", :size => "中", :base => 1,  :range => 0x2776..0x277f   },
      {:shape => "●", :size => "中", :base => 11, :range => 0x24eb..0x24f4   },
      {:shape => "●", :size => "中", :base => 0,  :range => 0x1f10c..0x1f10c }, # 0 がもう一つある
      {:shape => "●", :size => "小", :base => 1,  :range => 0x278a..0x2793   },
      {:shape => "◎", :size => "中", :base => 1,  :range => 0x24f5..0x24fe   },
    ]
  end

  # テーブルがあっているか目視で確認する用
  def info
    list.each do |e|
      range = e[:base] .. e[:base] + e[:range].size - 1
      str = e[:range].to_a.pack("U*")
      p [e[:shape], e[:size], range, str]
    end
  end

  # 置換用のハッシュを準備
  def replace_hash
    @replace_hash ||= list.inject({}) { |a, e|
      a.merge(e[:range].each.with_index.inject({}) { |a, (v, i)|
          a.merge([v].pack("U") => "(#{e[:base] + i})")
        })
    }
  end

  # 変換テスト
  def test
    list.each do |e|
      a = e[:range].to_a.pack("U*")
      b = replace(a)
      p [a, b]
    end
  end
end

if $0 == __FILE__
  MaruReplacer.new.replace("①") # => "(1)"
  MaruReplacer.new.test
end
# >> ["⓪", "(0)"]
# >> ["①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳", "(1)(2)(3)(4)(5)(6)(7)(8)(9)(10)(11)(12)(13)(14)(15)(16)(17)(18)(19)(20)"]
# >> ["㉑㉒㉓㉔㉕㉖㉗㉘㉙㉚㉛㉜㉝㉞㉟", "(21)(22)(23)(24)(25)(26)(27)(28)(29)(30)(31)(32)(33)(34)(35)"]
# >> ["㊱㊲㊳㊴㊵㊶㊷㊸㊹㊺㊻㊼㊽㊾㊿", "(36)(37)(38)(39)(40)(41)(42)(43)(44)(45)(46)(47)(48)(49)(50)"]
# >> ["🄋", "(0)"]
# >> ["➀➁➂➃➄➅➆➇➈➉", "(1)(2)(3)(4)(5)(6)(7)(8)(9)(10)"]
# >> ["⓿", "(0)"]
# >> ["❶❷❸❹❺❻❼❽❾❿", "(1)(2)(3)(4)(5)(6)(7)(8)(9)(10)"]
# >> ["⓫⓬⓭⓮⓯⓰⓱⓲⓳⓴", "(11)(12)(13)(14)(15)(16)(17)(18)(19)(20)"]
# >> ["🄌", "(0)"]
# >> ["➊➋➌➍➎➏➐➑➒➓", "(1)(2)(3)(4)(5)(6)(7)(8)(9)(10)"]
# >> ["⓵⓶⓷⓸⓹⓺⓻⓼⓽⓾", "(1)(2)(3)(4)(5)(6)(7)(8)(9)(10)"]
