module Cryptobroker::Broker
  class Basic
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

    attr_reader :type, :price

    def initialize(type = :base, pr = :median)
      @type = type
      @price = pr
    end

    def reset(amount, market)
      @balance = @type == :base ? Balance.new(amount, 0) : Balance.new(0, amount)
      @market = market
      @tr = 0
    end

    def pay_out
      last_price = @market.last.send @price
      if @type == :base && @balance.quote > 0
        transaction :buy_all, nil, nil, last_price
      elsif @type == :quote && @balance.base > 0
        transaction :sell_all, nil, nil, last_price
      end
      {amount: @balance.send(@type), transactions: @tr}
    end

    def sell(timestamp, params = {})
      transaction :sell_all, timestamp, params
    end

    def buy(timestamp, params = {})
      transaction :buy_all, timestamp, params
    end

    protected

    def transaction(tr_method, timestamp, params = {}, price = nil)
      price = find_price timestamp, params if price.nil?
      return if price.nil?
      @tr += 1
      send tr_method, price
    end

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
  end
end