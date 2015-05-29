require_relative 'simple'
require_relative 'fee_mixin'

module Cryptobroker::Broker::Backtesting
  class TransactionFee < Simple
    include Cryptobroker::Broker::Backtesting::FeeMixin

    def initialize(type, price, start_amount, fee)
      super(type, price, start_amount)
      initialize_fee_mixin(fee)
    end

    protected

    def achieve_base_target(price)
      @base += base_equivalent(price) * buy_fee_factor
      @quote = 0.to_d
    end

    def achieve_quote_target(price)
      @quote += quote_equivalent(price) * sell_fee_factor
      @base = 0.to_d
    end
  end
end