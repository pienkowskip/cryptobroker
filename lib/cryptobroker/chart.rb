require 'thread'
require 'monitor'
require_relative '../illegal_state_error'
require_relative 'utility/logging'
require_relative 'chart/buffered'

class Cryptobroker::Chart
  include MonitorMixin
  include Cryptobroker::Utility::Logging

  attr_reader :beginning, :timeframe

  def initialize(downloader, market_id, beginning, timeframe, safety_lag = 20, buffer_size = 4096)
    super()
    @downloader, @market_id, @beginning, @timeframe, @safety_lag = downloader, market_id, beginning, timeframe, safety_lag
    synchronize do
      @listeners = []
      @buffer = Buffered.new @beginning, @timeframe, buffer_size
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
    logger.debug { 'Chart (market id: [%d], timeframe: [%d], started: [%s]) started.' % [@market_id, @timeframe, @beginning] }
  end

  def get(idx)
    synchronize { [@buffer.slice_from(idx == 0 ? 0 : @buffer.map_total_index(idx)), @buffer.total_size, @updated] }
  end

  def register_listener(listener)
    synchronize do
      @listeners.push listener
      listener.notice @buffer.total_size if @buffer.total_size > 0
    end
  end

  def remove_listener(listener)
    synchronize { @listeners.delete listener }
  end

  def notice(trades, updated)
    @queue.push [trades, updated]
  end

  def terminate
    synchronize do
      raise IllegalStateError, 'terminating chart with registered listeners' unless @listeners.empty?
      @requester.terminate.join
      @handler.terminate.join
    end
    logger.debug { 'Chart (market id: [%d], timeframe: [%d], started: [%s]) terminated.' % [@market_id, @timeframe, @beginning] }
  end

  private

  def handle_notice(trades, updated)
    synchronize do
      new_bars = @buffer.total_size
      trades.each { |trade| @buffer.append trade.timestamp, trade.price, trade.amount }
      @buffer.finish_until updated - @safety_lag
      new_bars = @buffer.total_size - new_bars
      @updated = updated
      if new_bars > 0
        logger.debug { 'Chart (market id: [%d], timeframe: [%d], started: [%s]) developed [%d] new bars of [%d] all bars.' % [@market_id, @timeframe, @beginning, new_bars, @buffer.total_size] }
        @listeners.each { |listener| listener.notice @buffer.total_size }
      end
    end
  end
end