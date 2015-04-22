require 'monitor'
require_relative '../../logging'
require_relative '../../api/error'
require_relative 'confirmator'

module Cryptobroker::Broker
  class Smart
    class Trader
      include Cryptobroker::Logging
      include MonitorMixin

      FAST_RETRY_DELAY = 3
      SLOW_RETRY_DELAY = 10
      DEFAULTS = {
          signal_price_period: 0.5,
          active_trading_refresh: 20,
          active_trading_spread_factor: 0.3
      }

      def initialize(conf, api, investor)
        super()
        @api, @investor = api, investor
        @couple = ActiveRecord::Base.with_connection { @investor.market.couple }
        @signal_price_period = conf.fetch :signal_price_period, DEFAULTS[:signal_price_period] * @investor.timeframe
        @active_trading_refresh = conf.fetch :active_trading_refresh, DEFAULTS[:active_trading_refresh]
        @spread_factor = conf.fetch :active_trading_spread_factor, DEFAULTS[:active_trading_spread_factor]
        @confirmator = Cryptobroker::Broker::Smart::Confirmator.new self, @api, @couple
        synchronize do
          @thread = nil
          @order = nil
          @balance_changes = []
        end
      end

      def cancel
        synchronize do
          unless @thread.nil?
            @thread.terminate
            @thread = nil
          end
          cancel_order
        end
      end

      def handle_order(type, timestamp, price)
        synchronize do
          cancel
          @thread = Thread.new do
            traded = signal_price_trading type, timestamp, price
            traded = active_trading type until traded
            logger.debug { 'Broker of investor [%s] finished execution of [%s] order.' % [@investor.name, type] }
            synchronize { @thread = nil }
          end
          @thread.abort_on_exception = true
        end
        logger.debug { 'Broker of investor [%s] scheduled for execution [%s] order.' % [@investor.name, type] }
      end

      def confirm_order(archived)
        synchronize do
          completed = archived.base_change != 0 || archived.quote_change != 0
          ActiveRecord::Base.with_connection do
            Cryptobroker::Model::Balance.transaction do
              if completed
                last = @investor.balances.last
                balance = @investor.balances.create!(
                    {base: last.base + archived.base_change,
                     quote: last.quote + archived.quote_change,
                     timestamp: archived.timestamp})
                balance.create_trade!(
                    {type: archived.type.to_s,
                     amount: archived.base_completed,
                     price: archived.price})
              end
              @balance_changes.reject! { |id, _, _| id == archived.id }
              #TODO: save new balance changes to db.
            end
          end
          if completed
            logger.info { 'Broker of investor [%s] completed execution of [%s] order with price [%f] for amount [%f].' %
                [@investor.name, archived.type, archived.price, archived.base_completed] }
          else
            logger.debug { 'Broker of investor [%s] confirmed cancellation of intact [%s] order.' % [@investor.name, archived.type] }
          end
        end
      end

      private

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
        synchronize do
          cancel_order
          amount = balance[type == :buy ? 1 : 0]
          # logger.debug { 'Broker of investor [%s] mocked [%s] order with price [%f] for amount [%f].' %
          #     [@investor.name, type, price, amount] }
          # return false
          @order = @api.send :"place_#{type}_order", @couple, price, amount
          #TODO: save order to db.
          logger.debug { 'Broker of investor [%s] placed [%s] order with price [%f] for amount [%f].' %
              [@investor.name, @order.type, @order.price, @order.base_amount] }
          cancel_order if @order.completed?
          !!@order.completed?
        end
      end

      def cancel_order
        synchronize do
          return true if @order.nil?
          order = @order.completed? ? nil : @api.open_orders(@couple).find { |o| o.id == @order.id }
          cancelled = @api.cancel_order @order.id
          if cancelled
            @order = order unless order.nil?
            change = [@order.base_completed, @order.quote_completed]
            logger.debug { 'Broker of investor [%s] cancelled [%s] order with price [%f] for pending amount [%f].' %
                [@investor.name, @order.type, @order.price, @order.base_pending] }
          else
            change = [@order.base_amount, @order.quote_amount]
            logger.debug { 'Broker of investor [%s] assumes that [%s] order with price [%f] for amount [%f] was completed.' %
                [@investor.name, @order.type, @order.price, @order.base_amount] }
          end
          if @order.type == :buy
            change[1] = -change[1]
          else
            change[0] = -change[0]
          end
          change.unshift @order.id
          @balance_changes.push change
          #TODO: save new balances changes to db & remove order.
          @confirmator.confirm @order.id, @order.timestamp
          @order = nil
          cancelled
        end
      rescue Cryptobroker::API::RecoverableError
        sleep FAST_RETRY_DELAY
        retry
      end

      def ticker
        @api.ticker @couple
      end

      def signal_price_trading(type, timestamp, price)
        diff = ->() { @signal_price_period - (Time.now - timestamp) }
        return false if diff[] <= 0 || price.nil?
        return true if place_order type, send(:"#{type}_signal_price", price)
        duration = diff[]
        sleep duration if duration > 0
        !cancel_order
      rescue Cryptobroker::API::RecoverableError
        sleep SLOW_RETRY_DELAY
        retry
      end

      def sell_signal_price(price)
        tck = ticker
        price < tck.bid ? tck.bid : price
      end

      def buy_signal_price(price)
        tck = ticker
        price > tck.ask ? tck.ask : price
      end

      def active_trading(type)
        return true if place_order type, send(:"#{type}_active_price")
        sleep @active_trading_refresh
        !cancel_order
      rescue Cryptobroker::API::RecoverableError
        sleep SLOW_RETRY_DELAY
        retry
      end

      def sell_active_price()
        tck = ticker
        tck.ask - tck.spread * @spread_factor
      end

      def buy_active_price()
        tck = ticker
        tck.bid + tck.spread * @spread_factor
      end
    end
  end
end