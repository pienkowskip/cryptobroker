require 'bigdecimal'
require 'bigdecimal/util'

module Cryptobroker::Broker
  module Backtesting
    module FeeMixin
      attr_reader :fee, :buy_fee_factor, :sell_fee_factor

      def initialize_fee_mixin(fee)
        @fee = fee.to_d
        raise ArgumentError, 'transaction fee not in (0...1)' unless (0...1).include?(@fee)
        @buy_fee_factor = 1 / (1 + @fee)
        @sell_fee_factor = 1 - @fee
      end
    end
  end
end