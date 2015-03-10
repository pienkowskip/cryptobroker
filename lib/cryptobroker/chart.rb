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

  def initialize(downloader, market_id, beginning, timeframe, safety_lag = 20)
    super()
    @downloader = downloader
    @market_id = market_id
    @beginning = beginning
    @timeframe = timeframe
    @safety_lag = safety_lag
    @last = Bar.new @beginning, @timeframe
    synchronize do
      @indicators = []
      @chart = []
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
        logger.debug @timeframe - (diff[] % @timeframe) + @safety_lag
        sleep @timeframe - (diff[] % @timeframe) + @safety_lag
        @downloader.request_update(@market_id)
      end
    end
    @requester.abort_on_exception = true
  end

  def get(bar_index)
    size, updated = synchronize do
      [@chart.size, @updated]
    end
    enum_for :get_until, bar_index, size, updated
  end

  def register_indicator(indicator)
    synchronize do
      @indicators.push indicator
    end
  end

  def notice(trades, updated)
    @queue.push [trades, updated]
  end

  private

  def handle_notice(trades, updated)
    news = []
    finish = ->(timestamp) do
      while timestamp >= @last.end
        unless @last.empty?
          @last.send :finish
          news.push @last
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
      @chart.concat news
      @updated = updated
      @indicators.each { |indicator| indicator.notice @updated }
    end
  end

  def get_until(idx, size, updated)
    while idx < size do
      yield @chart[idx]
      idx += 1
    end
    updated
  end

end