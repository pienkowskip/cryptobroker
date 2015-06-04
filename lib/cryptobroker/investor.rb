require 'thread'
require_relative 'utility/logging'

class Cryptobroker::Investor
  include Cryptobroker::Utility::Logging

  def initialize(chart, indicator, broker, name)
    @chart, @indicator, @broker, @name = chart, indicator, broker, name
    @last_signal = Time.now
    @queue = Queue.new
    @chart.register_listener self
    @handler = Thread.new do
      loop do
        handle_notice @queue.pop
      end
    end
    @handler.abort_on_exception = true
    logger.debug { 'Investor [%s] started.' % @name }
  end

  def notice(size)
    @queue.push size
  end

  def terminate
    @chart.remove_listener self
    @handler.terminate.join
    @broker.terminate
    logger.debug { 'Investor [%s] terminated.' % @name }
  end

  def abort
    @handler.terminate
    @broker.abort
    logger.debug { 'Investor [%s] aborted.' % @name }
  end

  private

  def handle_notice(size)
    return unless size > @indicator.finished
    bars = @chart.get(@indicator.finished)[0]
    return if bars.empty?
    @indicator.append(bars) do |type, timestamp, params|
      next if @last_signal >= timestamp
      logger.info { 'Indicator [%s] of investor [%s] raised [%s] signal generated at [%s].' % [@indicator.name, @name, type, timestamp] }
      @broker.public_send type, timestamp, params
      @last_signal = timestamp
    end
  end
end