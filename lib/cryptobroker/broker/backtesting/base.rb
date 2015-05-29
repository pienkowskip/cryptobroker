require 'bigdecimal'
require 'bigdecimal/util'
require_relative '../../../illegal_state_error'

module Cryptobroker::Broker
  module Backtesting
    class Base
      attr_reader :type, :price

      def initialize(type, price)
        raise ArgumentError, 'invalid broker type' unless [:base, :quote].include?(type)
        @type, @price = type, price
      end

      def reset(bars)
        @bars = bars
        @result = nil
        @last_tr_target = @type
        @last_tr_idx = -1
      end

      def result
        reset_check
        return @result unless @result.nil?
        @result = finalize.freeze
      end

      def sell(idx)
        transaction(:quote, idx)
      end

      def buy(idx)
        transaction(:base, idx)
      end

      protected

      def transaction(target, idx)
        reset_check
        raise IllegalStateError, 'broker already finalized' unless @result.nil?
        raise ArgumentError, 'idx is out of market chart' unless (0...@bars.size).include?(idx)
        raise ArgumentError, 'idx is prior to last transaction' unless idx > @last_tr_idx
        @last_tr_idx = idx
        return false if target == @last_tr_target
        @last_tr_target = target
        perform_transaction(target, idx)
      end

      def reset_check
        raise IllegalStateError, 'reset broker before performing operation' if @bars.nil?
      end

      def price_at(idx)
        @bars.fetch(idx).public_send(@price).to_d
      end
    end
  end
end