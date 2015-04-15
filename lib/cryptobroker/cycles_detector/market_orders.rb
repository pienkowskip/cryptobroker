require 'bigdecimal'
require 'bigdecimal/util'

module Cryptobroker::CyclesDetector
  class MarketOrders
    class Order
      attr_reader :price, :base

      def initialize(price, base)
        @price = price.to_d
        @base = base.to_d
      end

      def quote
        @price * @base
      end
    end

    FEE_FACTOR = 0.998
    attr_reader :market

    def initialize(market, api)
      @market = market
      @api = api
      @timestamp = nil
      @asks = []
      @bids = []
    end

    def update
      rt = 2
      begin
        rt -= 1
        orders = @api.orders @market.couple
      rescue => e
        retry if rt > 0
        raise e
      end
      @timestamp = orders[:timestamp]
      @asks = orders[:asks].map { |price, amount| Order.new price, amount }
      @bids = orders[:bids].map { |price, amount| Order.new price, amount }
    end

    def instant_fake_buy(quote)
      base = 0.to_d
      @asks.each do |ask|
        if ask.quote > quote
          base += (quote / ask.price) * FEE_FACTOR
          quote = 0.to_d
          break
        end
        base += ask.base * FEE_FACTOR
        quote -= ask.quote
      end
      raise 'insufficient' if quote > 0
      base
    end

    def instant_fake_sell(base)
      quote = 0.to_d
      @bids.each do |bid|
        if bid.base > base
          quote += base * bid.price * FEE_FACTOR
          base = 0.to_d
          break
        end
        quote += bid.quote * FEE_FACTOR
        base -= bid.base
      end
      raise 'insufficient' if base > 0
      quote
    end
  end
end