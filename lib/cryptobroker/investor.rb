require 'thread'
require_relative 'logging'

class Cryptobroker::Investor
  include Cryptobroker::Logging

  def initialize(chart, indicator, broker)
    @chart, @indicator, @broker = chart, indicator, broker
    @last_signal = Time.now - 60*60*48
    @queue = Queue.new
    @chart.register_indicator self
    @handler = Thread.new do
      loop do
        handle_notice @queue.pop
      end
    end
    @handler.abort_on_exception = true
  end

  def notice(size)
    @queue.push size
  end

  private

  def handle_notice(size)
    return unless size > @indicator.finished
    bars, size, updated = @chart.get @indicator.finished
    return if bars.empty?
    logger.debug { 'Notice - buffered bars: [%d], size: [%d], updated at: [%s]' % [bars.size, size, updated.to_s] }
    sigs = 0
    @indicator.append(bars) do |type, timestamp, params|
      next if @last_signal >= timestamp
      sigs += 1
      @broker.send type, timestamp, params
      @last_signal = timestamp
    end
    logger.info { 'Indicator [%s] stats: new sigs [%d], base [%.3f], quote [%.3f]' % [@indicator.name, sigs, *@broker.pay_out] }
  end
end