require 'thread'
require 'monitor'
require_relative '../logging'

module Cryptobroker::Broker
  class Smart
    include MonitorMixin
    include Cryptobroker::Logging

    MORE_SIGNALS_LAG = 0.3
    DEFAULT_SIGNAL_PRICE_PERIOD = 0.5


    def initialize(conf, api, investor)
      super()
      @api, @investor = api, investor
      @couple = ActiveRecord::Base.with_connection { @investor.market.couple }
      @signal_price_period = conf.fetch :signal_price_period, DEFAULT_SIGNAL_PRICE_PERIOD * @investor.timeframe
      logger.debug @signal_price_period
      @signals = Queue.new
      synchronize do
        @trader = nil
        @order = nil
      end
      @manager = Thread.new do
        loop do
          signal = @signals.pop
          sleep MORE_SIGNALS_LAG
          begin
            loop { signal = @signals.pop true }
          rescue ThreadError
            handle_signal *signal
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
      synchronize do
        unless @trader.nil?
          @trader.terminate
          @trader = nil
        end
        cancel_order
      end
    end

    private

    def handle_signal(type, timestamp, price)
      cancel
      synchronize do
        @trader = Thread.new do
          if signal_price_trading type, timestamp, price
            synchronize { @trader = nil }
          else
            # active_trading
          end
        end
        @trader.abort_on_exception = true
      end
      logger.debug { 'Broker of investor [%s] scheduled for execution [%s] order.' % [@investor.name, type] }
    end

    def place_order(type, price)
      logger.debug 'inv [%s] placing [%s] order with price [%f]' % [@investor.name, type, price]
      #1. read amount for order
      #2. place order and setup @order
    end

    def cancel_order
      #1. Read from open orders and check if exists.
      #2. Try to cancel order.
      #3. Setup order for confirmation.
      # what to do on timeout? - I recommend to retry canceling endlessly.
      synchronize do
        return true if @order.nil?
      end
    end

    def signal_price_trading(type, timestamp, price)
      diff = ->() { @signal_price_period - (Time.now - timestamp) }
      return false if diff[] <= 0 || price.nil?
      place_order type, send(:"#{type}_signal_price", price)
      duration = diff[]
      sleep duration if duration > 0
      cancel_order
      return false
    end

    def sell_signal_price(price)
      tck = @api.ticker @couple
      price < tck[:bid] ? tck[:bid] : price
    end

    def buy_signal_price(price)
      tck = @api.ticker @couple
      price > tck[:ask] ? tck[:ask] : price
    end

    def sell_active_price(ticker)

    end

    def buy_active_price(ticker)

    end
  end
end
