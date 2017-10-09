class TailFEvent
  def initialize file, &block
    @file = file
    @block = block
    @queue = Queue.new
    @sending = {}
    Thread.new { _run }
    Thread.new do
      while (kd = @queue.deq)
        key, data = kd
        result = @block.call data
        _send "ok/#{key}/#{result}"
      end
    end
  end

  def emit msg
    key = rand.to_s
    pings = []
    oks = Queue.new
    @sending[key] = [pings, oks]
    _send "emit/#{key}/#{msg}"
    sleep 0.2
    result = Array.new(pings.size) { oks.deq }
    @sending.delete key
    result
  end

  def _send data
    File.open(@file, 'a') { |f| f.puts data }
  end

  def _ondata msg
    type, key, data = msg.split('/', 3)
    if type == 'emit'
      _send "ping/#{key}"
      @queue << [key, data]
    else
      pings, oks = @sending[key]
      if type == 'ping'
        pings << 1 if pings
      elsif type == 'ok'
        oks << data if oks
      end
    end
  end

  def _run
    loop do
      io = IO.popen ['tail', '-n0', '-f', @file], 'r'
      loop { _ondata io.gets[0...-1] }
    end
  end
end
