require 'thread'
require 'monitor'
require_relative '../logging'

module Cryptobroker::Broker
  class Smart
    include MonitorMixin
    include Cryptobroker::Logging

    CONCURRENCY_LAG = 0.3
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
        @balance_changes = []
      end
      @manager = Thread.new do
        loop do
          signal = @signals.pop
          sleep CONCURRENCY_LAG
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
        begin
          cancel_order
        rescue
          retry #TODO: setup decent lag?
        end
      end
    end

    private

    def handle_signal(type, timestamp, price)
      cancel
      synchronize do
        @trader = Thread.new do
          unless signal_price_trading type, timestamp, price
            active_trading type
          end
          synchronize { @trader = nil }
        end
        @trader.abort_on_exception = true
      end
      logger.debug { 'Broker of investor [%s] scheduled for execution [%s] order.' % [@investor.name, type] }
    end

    def balance
      synchronize do
        db_balance = ActiveRecord::Base.with_connection { @investor.balances.last }
        base, quote = db_balance.base, db_balance.quote
        @balance_changes.each do |change|
          base += change[1]
          quote += change[2]
        end
        return base, quote
      end
    end

    def place_order(type, price)
      logger.debug 'inv [%s] placing [%s] order with price [%f]' % [@investor.name, type, price]
      synchronize do
        cancel_order
        amount = balance[type == :buy ? 1 : 0]
        @order = @api.send :"place_#{type}_order", @couple, price, amount
        # setup balance change? or at cancel?
      end
    end

    def cancel_order
      synchronize do
        return true if @order.nil?
        order = @api.open_orders(@couple).find { |o| o[:id] == @order[:id] }
        cancelled = @api.cancel_order @order[:id]
        if cancelled
          # assume that order was fully executed
        else
          # order partially (or no) executed - use order var
        end
        # setup new balance & order for confirmation
        @order = nil
        cancelled
      end
    end

    def signal_price_trading(type, timestamp, price)
      diff = ->() { @signal_price_period - (Time.now - timestamp) }
      return false if diff[] <= 0 || price.nil?
      place_order type, send(:"#{type}_signal_price", price)
      #if order is finished you can cancel immediately
      duration = diff[]
      sleep duration if duration > 0
      cancelled = begin
        cancel_order
      rescue
        sleep CONCURRENCY_LAG
        retry
      end
      !cancelled
    end

    def sell_signal_price(price)
      tck = @api.ticker @couple
      price < tck[:bid] ? tck[:bid] : price
    end

    def buy_signal_price(price)
      tck = @api.ticker @couple
      price > tck[:ask] ? tck[:ask] : price
    end

    def active_trading(type)
      false
    end

    def sell_active_price()

    end

    def buy_active_price()

    end
  end
end
