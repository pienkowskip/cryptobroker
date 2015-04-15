require 'thread'
require_relative 'logging'

class Cryptobroker::Investor
  include Cryptobroker::Logging

  def initialize(chart, indicator, broker, name)
    @chart, @indicator, @broker, @name = chart, indicator, broker, name
    @last_signal = Time.now
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
    bars = @chart.get(@indicator.finished)[0]
    return if bars.empty?
    @indicator.append(bars) do |type, timestamp, params|
      next if @last_signal >= timestamp
      logger.info { 'Indicator [%s] of investor [%s] raised [%s] signal generated at [%s].' % [@indicator.name, @name, type, timestamp] }
      @broker.send type, timestamp, params
      @last_signal = timestamp
    end
  end
end