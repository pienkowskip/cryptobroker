require 'thread'
require 'monitor'
require_relative 'logging'

class Cryptobroker::Chart
  class Bar
    attr_reader :start, :duration, :open, :high, :low, :close, :volume, :weighted, :median

    def initialize(start, duration)
      @start = start
      @duration = duration
    end

    def empty?
      @open.nil?
    end

    def end
      @start + @duration
    end

    private

    def first(price, amount)
      @open = price
      @high = price
      @low = price
      @weighted = 0
      @volume = 0
      @median = {}
    end

    def append(price, amount)
      first price, amount if empty?
      @weighted += price * amount
      @volume += amount
      @median[price] = @median.fetch(price, 0) + amount
      @close = price
      @low = price if price < @low
      @high = price if price > @high
    end

    def finish
      return if empty?

      @weighted /= @volume

      sum = 0
      median = []
      @median.keys.sort.each do |price|
        sum += @median[price]
        if sum > @volume / 2
          median.push price
          break
        elsif sum == @volume / 2
          median.push price
        end
      end
      @median = median.reduce(:+) / median.size
    end
  end

  include MonitorMixin
  include Cryptobroker::Logging

  attr_reader :beginning, :timeframe

  def initialize(downloader, market_id, beginning, timeframe, safety_lag = 20, buffer_size = 4096)
    super()
    @downloader, @market_id, @beginning, @timeframe, @safety_lag, @buffer_size = downloader, market_id, beginning, timeframe
    @safety_lag, @buffer_size = safety_lag, buffer_size
    @last = Bar.new @beginning, @timeframe
    synchronize do
      @indicators = []
      @buffer = []
      @size = 0
      @updated = nil
    end
    @queue = Queue.new
    @handler = Thread.new do
      loop do
        handle_notice *@queue.pop
      end
    end
    @handler.abort_on_exception = true
    @downloader.register_chart self, @market_id
    @requester = Thread.new do
      diff = -> { Time.now - @beginning }
      while diff[] < 0
        sleep -diff[]
      end
      loop do
        sleep @timeframe - (diff[] % @timeframe) + @safety_lag
        @downloader.request_update @market_id
      end
    end
    @requester.abort_on_exception = true
  end

  def get(idx)
    synchronize { [buffer_copy(idx - (@size - @buffer.size)), @size, @updated] }
  end

  def register_indicator(indicator)
    synchronize do
      @indicators.push indicator
      indicator.notice @size if @size > 0
    end
  end

  def notice(trades, updated)
    @queue.push [trades, updated]
  end

  private

  def buffer_copy(i)
    raise IndexError, 'index outside of buffer bounds' if i < 0 || i > @buffer.size
    @buffer[i, @buffer.size - i]
  end

  def handle_notice(trades, updated)
    new_buffer, new_size = synchronize { [buffer_copy(0), @size] }
    finish = ->(timestamp) do
      while timestamp >= @last.end
        unless @last.empty?
          @last.send :finish
          new_buffer.shift if new_buffer.size >= @buffer_size
          new_buffer.push @last
          new_size += 1
        end
        @last = Bar.new @last.end, @timeframe
      end
    end
    trades.each do |trade|
      raise ArgumentError, 'given timestamp is out of processable range' if trade.timestamp < @last.start
      finish[trade.timestamp]
      @last.send :append, trade.price, trade.amount
    end
    finish[updated - @safety_lag]
    synchronize do
      new_bars = new_size - @size
      @updated = updated
      if new_bars > 0
        @size = new_size
        @buffer = new_buffer
        logger.debug { 'Chart (market id: [%d], timeframe: [%d], started: [%s]) developed [%d] new bars of [%d] all bars.' % [@market_id, @timeframe, @beginning, new_bars, @size] }
        @indicators.each { |indicator| indicator.notice @size }
      end
    end
  end
end