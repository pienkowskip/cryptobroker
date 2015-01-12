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

    attr_reader :type, :price

    def initialize(type = :base, pr = :median)
      @type = type
      @price = pr
    end

    def reset(amount, market)
      @balance = @type == :base ? Balance.new(amount, 0) : Balance.new(0, amount)
      @market = market
      @tr = 0
      update_last
    end

    def pay_out
      @last
    end

    def sell(timestamp, params = {})
      price = find_price timestamp, params
      return if price.nil?
      @tr += 1
      update_last if @type == :base
      sell_all price
    end

    def buy(timestamp, params = {})
      price = find_price timestamp, params
      return if price.nil?
      @tr += 1
      update_last if @type == :quote
      buy_all price
    end

    protected

    def buy_all(price)
      @balance.base += @balance.quote / price
      @balance.empty_quote
    end

    def sell_all(price)
      @balance.quote += @balance.base * price
      @balance.empty_base
    end

    def find_price(timestamp, params)
      # idx = @market.index { |i| timestamp < i.end }
      # return nil if idx.nil?
      # @market[idx].send @price
      chunk = @market[params[:idx]+1]
      return nil if chunk.nil?
      chunk.send @price
    end

    def update_last
      @last = {amount: @balance.send(@type), transactions: @tr}
    end
  end
end