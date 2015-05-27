require 'monitor'
require_relative '../../logging'
require_relative '../../api/errors'
require_relative 'confirmator'

module Cryptobroker::Broker
  class Smart
    class Trader
      class BalanceChange
        attr_reader :order_id, :timestamp, :base, :quote

        def initialize(order, base, quote)
          @order_id, @timestamp = order.id, order.timestamp
          @base, @quote = base, quote
          if order.type == :buy
            @quote = -@quote
          else
            @base = -@base
          end
        end
      end

      class InvalidBalanceError < StandardError
      end

      include Cryptobroker::Logging
      include MonitorMixin

      FAST_RETRY_DELAY = 3
      SLOW_RETRY_DELAY = 10
      DEFAULTS = {
          signal_price_period: 0.5,
          active_trading_refresh: 30,
          active_trading_spread_factor: 0.2
      }.freeze

      def initialize(conf, api, investor)
        super()
        @api, @investor = api, investor
        @signal_price_period = conf.fetch :signal_price_period, DEFAULTS[:signal_price_period] * @investor.timeframe
        @active_trading_refresh = conf.fetch :active_trading_refresh, DEFAULTS[:active_trading_refresh]
        @spread_factor = conf.fetch :active_trading_spread_factor, DEFAULTS[:active_trading_spread_factor]

        ActiveRecord::Base.with_connection do
          @couple = @investor.market.couple
          vars_init = {'order' => nil, 'balance_changes' => [], 'ongoing_signal' => nil}
          vars = Hash[@investor.variables.where(name: vars_init.keys).map { |var| [var.name, var] }]
          vars_init.each do |name, default|
            var = vars[name]
            if var.nil?
              var = @investor.variables.build name: name
              var.set_value! default
            end
            instance_variable_set :"@db_#{name}", var
          end
        end

        @confirmator = Cryptobroker::Broker::Smart::Confirmator.new self, @api, @couple
        synchronize do
          @invalid_balance = false
          @thread = nil
          @order = @db_order.get_value
          @balance_changes = @db_balance_changes.get_value
          @balance_changes.each { |change| @confirmator.confirm change.order_id, change.timestamp }
          unless @order.nil?
            @thread = Thread.new do
              synchronize do
                cancel_order
                @thread = nil
              end
            end
            @thread.abort_on_exception = true
            logger.debug { 'Broker of investor [%s] restored unfinished order. Scheduled for cancellation.' % [@investor.name] }
          end
        end
      end

      def cancel
        synchronize do
          ActiveRecord::Base.with_connection { @db_ongoing_signal.set_value! nil }
          return unless perform_cancel
          logger.info { 'Broker of investor [%s] cancelled execution of current order.' % @investor.name }
        end
      end

      def abort
        return unless perform_cancel
        logger.warn { 'Broker of investor [%s] interrupted execution of current order.' % @investor.name }
      end

      def handle_order(type, timestamp, price)
        synchronize do
          if @invalid_balance
            logger.warn { 'Broker of investor [%s] is suspended because of insufficient funds. Requested [%s] order discarded.' %
                [@investor.name, type] }
            return
          end
          cancel
          ActiveRecord::Base.with_connection { @db_ongoing_signal.set_value! [type, timestamp, price].freeze }
          @thread = Thread.new do
            begin
              logger.info { 'Broker of investor [%s] started execution of [%s] order.' % [@investor.name, type] }
              logger.debug { 'Broker of investor [%s] is starting signal price trading for [%s] order.' % [@investor.name, type] }
              traded = signal_price_trading type, timestamp, price
              logger.debug { 'Broker of investor [%s] %s finished signal price trading for [%s] order.' %
                  [@investor.name, traded ? 'completely' : 'incompletely', type] }
              unless traded
                logger.debug { 'Broker of investor [%s] is starting active price trading for [%s] order.' % [@investor.name, type] }
                traded = active_trading type until traded
                logger.debug { 'Broker of investor [%s] completely finished signal price trading for [%s] order.' % [@investor.name, type] }
              end
            rescue InvalidBalanceError
              synchronize do
                @invalid_balance = true
                ActiveRecord::Base.with_connection { @db_ongoing_signal.set_value! nil }
                logger.error { 'Broker of investor [%s] suspended orders execution because of insufficient funds. Check account balance and restart investor.' %
                    @investor.name }
                cancel_order
                @thread = nil
              end
            else
              synchronize do
                ActiveRecord::Base.with_connection { @db_ongoing_signal.set_value! nil }
                @thread = nil
                logger.info { 'Broker of investor [%s] successfully finished execution of [%s] order.' % [@investor.name, type] }
              end
            end
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
              @balance_changes.reject! { |change| change.order_id == archived.id }
              @db_balance_changes.set_value! @balance_changes
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

      def terminate
        synchronize do
          abort
          @confirmator.terminate
        end
      end

      def ongoing_signal
        synchronize { @db_ongoing_signal.get_value.freeze }
      end

      private

      def balance
        synchronize do
          db_balance = ActiveRecord::Base.with_connection { @investor.balances.last }
          base, quote = db_balance.base, db_balance.quote
          @balance_changes.each do |change|
            base += change.base
            quote += change.quote
          end
          return base, quote
        end
      end

      def place_order(type, price)
        synchronize do
          cancel_order
          amount = balance[type == :buy ? 1 : 0]
          if amount <= 0 && @balance_changes.empty?
            logger.warn { 'Broker of investor [%s] can not place [%s] order because of zero balance.' % [@investor.name, type] }
            return true
          end
          begin
            @order = @api.public_send :"place_#{type}_order", @couple, price, amount
          rescue Cryptobroker::API::InvalidAmountError
            raise unless @balance_changes.empty?
            logger.warn { 'Broker of investor [%s] can not place [%s] order because of balance less than minimal offer.' % [@investor.name, type] }
            return true
          rescue Cryptobroker::API::InsufficientFundsError
            raise unless @balance_changes.empty?
            raise InvalidBalanceError
          end
          ActiveRecord::Base.with_connection { @db_order.set_value! @order }
          logger.debug { 'Broker of investor [%s] placed [%s] order with price [%f] for amount [%f].' %
              [@investor.name, @order.type, @order.price, @order.base_amount] }
          completed = @order.completed?
          cancel_order if completed
          !!completed
        end
      end

      def cancel_order
        synchronize do
          return true if @order.nil?
          order = @order.completed? ? nil : @api.open_orders(@couple).find { |o| o.id == @order.id }
          cancelled = @api.cancel_order @order.id
          if cancelled
            @order = order unless order.nil?
            change = BalanceChange.new @order, @order.base_completed, @order.quote_completed
            logger.debug { 'Broker of investor [%s] cancelled [%s] order with price [%f] for pending amount [%f].' %
                [@investor.name, @order.type, @order.price, @order.base_pending] }
          else
            change = BalanceChange.new @order, @order.base_amount, @order.quote_amount
            logger.debug { 'Broker of investor [%s] assumes that [%s] order with price [%f] for amount [%f] was completed.' %
                [@investor.name, @order.type, @order.price, @order.base_amount] }
          end
          @balance_changes.push change
          @order = nil
          ActiveRecord::Base.with_connection do
            Cryptobroker::Model::Variable.transaction do
              @db_balance_changes.set_value! @balance_changes
              @db_order.set_value! @order
            end
          end
          @confirmator.confirm change.order_id, change.timestamp
          cancelled
        end
      rescue Cryptobroker::API::RecoverableError => error
        logger.warn { 'Cancelling order of broker of investor [%s] failure. Will retry in %ds. Exception: %s (%s).' %
            [@investor.name, FAST_RETRY_DELAY, error.message, error.class] }
        sleep FAST_RETRY_DELAY
        retry
      end

      def perform_cancel
        trading = !@thread.nil?
        if trading
          @thread.terminate.join
          @thread = nil
        end
        cancel_order
        trading
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
      rescue Cryptobroker::API::RecoverableError => error
        logger.warn { 'Signal price trading of broker of investor [%s] for [%s] order failure. Will retry in %ds. Exception: %s (%s).' %
            [@investor.name, type, SLOW_RETRY_DELAY, error.message, error.class] }
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
      rescue Cryptobroker::API::RecoverableError => error
        logger.warn { 'Active price trading of broker of investor [%s] for [%s] order failure. Will retry in %ds. Exception: %s (%s).' %
            [@investor.name, type, SLOW_RETRY_DELAY, error.message, error.class] }
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