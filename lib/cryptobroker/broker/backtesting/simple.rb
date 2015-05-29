require_relative 'base'

module Cryptobroker::Broker::Backtesting
  class Simple < Base
    attr_reader :start_amount

    def initialize(type, price, start_amount)
      super(type, price)
      @start_amount = start_amount.to_d
    end

    def reset(bars)
      super(bars)
      @base, @quote = 0.to_d, 0.to_d
      instance_variable_set(:"@#{@type}", @start_amount)
      @tr_count = 0
    end

    protected

    def finalize
      if @last_tr_target == @type
        return instance_variable_get(:"@#{@type}"), @tr_count
      else
        return send(:"#{@type}_equivalent", price_at(@bars.size - 1)), @tr_count
      end
    end

    def perform_transaction(target, idx)
      @tr_count += 1
      send(:"achieve_#{target}_target", price_at(idx))
    end

    def achieve_base_target(price)
      @base += base_equivalent(price)
      @quote = 0.to_d
    end

    def achieve_quote_target(price)
      @quote += quote_equivalent(price)
      @base = 0.to_d
    end

    def base_equivalent(price)
      @quote / price
    end

    def quote_equivalent(price)
      @base * price
    end
  end
end