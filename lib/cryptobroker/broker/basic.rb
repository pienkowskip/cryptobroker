module Cryptobroker::Broker
  class Basic
    class Balance
      attr_accessor :base, :quote

      def initialize(b, q)
        @base = BigDecimal.new b
        @quote = BigDecimal.new q
      end

      def empty_base
        @base = BigDecimal.new 0
      end

      def empty_quote
        @quote = BigDecimal.new 0
      end
    end

    def initialize(type = :base)
      @type = type
    end

    def reset(amount, market, price = :median)
      @balance = @type == :base ? Balance.new(amount, 0) : Balance.new(0, amount)
      @market = market
      @price = price
      @tr = 0
      update_last
    end

    def pay_out
      @last
    end

    def sell(timestamp, params = {})
      price = find_price(timestamp)
      return if price.nil?
      @tr += 1
      update_last if @type == :base
      @balance.quote += @balance.base * price
      @balance.empty_base
    end

    def buy(timestamp, params = {})
      price = find_price(timestamp)
      return if price.nil?
      @tr += 1
      update_last if @type == :quote
      @balance.base += @balance.quote / price
      @balance.empty_quote
    end

    private

    def find_price(timestamp)
      idx = @market.index { |i| timestamp < i.end }
      return nil if idx.nil?
      @market[idx].send @price
    end

    def update_last
      @last = {amount: @balance.send(@type), transactions: @tr}
    end
  end
end