class Safekill
  def initialize(*options)
    @options = options
  end

  def run
    exec_flag = @options.delete("-x")
    @regexp = @options.first
    if @regexp.to_s.empty?
      puts "正規表現を指定してください。"
      return
    end
    process_ids = ps_aux
    if process_ids.empty?
      return
    end

    command = "sudo kill -9 #{process_ids.join(' ')}"
    if exec_flag
      `#{command}`.display
      puts "【実行後】"
      ps_aux
    else
      puts "本当に実行するには -x オプションをつけてください。"
    end
  end

  def ps_aux
    lines = `ps aux`.lines.find_all {|e| e.match(@regexp) }
    lines.reject!{|line|line.match(/^\w+\s+#{Process.pid}\b/)} # 自分を除去
    if lines.empty?
      puts "なし"
      return []
    end
    puts lines
    process_ids = lines.collect { |e|
      e.match(/^\S+\s+(\d+)/).captures.first.to_i
    }.sort.reverse
    process_ids - [Process.pid] # 自分を除去
  end

end

if $0 == __FILE__
  Safekill.new(*ARGV).run
end
