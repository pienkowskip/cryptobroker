require 'thread'
require_relative '../utility/logging'
require_relative 'smart/trader'

module Cryptobroker::Broker
  class Smart
    include Cryptobroker::Utility::Logging

    CONCURRENCY_DELAY = 0.3

    def initialize(conf, api, investor)
      @trader = Trader.new conf, api, investor
      @signals = begin
        queue, signal = Queue.new, @trader.ongoing_signal
        unless signal.nil?
          queue.push signal
          logger.info { 'Broker of investor [%s] restored [%s] signal generated at [%s].' % [investor.name, signal[0], signal[1]] }
        end
        queue
      end
      @manager = Thread.new do
        loop do
          signal = @signals.pop
          sleep CONCURRENCY_DELAY
          begin
            loop { signal = @signals.pop true }
          rescue ThreadError
            @trader.handle_order *signal
          end
        end
      end
      @manager.abort_on_exception = true
    end

    def buy(timestamp, params)
      @signals.push [:buy, timestamp, params[:price]]
    end

    def sell(timestamp, params)
      @signals.push [:sell, timestamp, params[:price]]
    end

    def cancel
      @trader.cancel
    end

    def abort
      @manager.terminate
      @trader.abort
    end

    def terminate
      @manager.terminate.join
      @trader.terminate
    end
  end
end
