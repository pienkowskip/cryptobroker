module Cryptobroker::Broker
  class Dummy
    class Balance
      attr_accessor :base, :quote

      def initialize(b, q)
        @base = b.to_d
        @quote = q.to_d
      end

      def empty_base
        @base = 0.to_d
      end

      def empty_quote
        @quote = 0.to_d
      end
    end

    def initialize(conf, api, investor)
      @balance = Balance.new(100, 0)
    end

    def pay_out
      return @balance.base, @balance.quote
    end

    def buy(timestamp, params)
      price = params[:price]
      @balance.base += @balance.quote / price
      @balance.empty_quote
    end

    def sell(timestamp, params)
      price = params[:price]
      @balance.quote += @balance.base * price
      @balance.empty_base
    end
  end
end