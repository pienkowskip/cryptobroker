require_relative 'base'

module Cryptobroker::Broker::Backtesting
  class Relative < Base
    include Cryptobroker::Broker::Backtesting::FeeMixin

    def initialize(type, price, fee)
      super(type, price)
      initialize_fee_mixin(fee)
    end

    def reset(bars)
      super
      @transactions = []
    end

    protected

    # = base/quote transitions =
    # == absolute broker ==
    # quote => base: (q / (1+fee)) / pr
    # base => quote: (b * (1-fee)) * pr
    # == relative base broker ==
    # quote => base: (lpr / pr) * (1/(1+fee)) - 1
    # base => quote: (1-fee) - 1
    # == relative quote broker ==
    # quote => base: (1/(1+fee)) - 1
    # base => quote: (pr / lpr) * (1-fee) - 1

    def finalize
      results = []
      status = @type
      price = nil
      next_tr = @transactions.shift
      @bars.each_index do |i|
        last_price = price
        price = price_at(i)
        if next_tr == i
          status = invert_target(status)
          if status == @type
            results << price_ratio(price, last_price) * fee_factor(status) - 1
          else
            results << fee_factor(status) - 1
          end
          next_tr = @transactions.shift
        else
          if status == @type
            results << 0
          else
            results << price_ratio(price, last_price) - 1
          end
        end
      end
      results
    end

    def invert_target(target)
      return :base if target == :quote
      return :quote if target == :base
      nil
    end

    def price_ratio(current, previous)
      return previous / current if @type == :base
      return current / previous if @type == :quote
      nil
    end

    def fee_factor(target)
      return buy_fee_factor if target == :base
      return sell_fee_factor if target == :quote
      nil
    end

    def perform_transaction(_, idx)
      @transactions << idx
    end
  end
end