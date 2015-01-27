module Cryptobroker::Model
  class LightTrade
    def self.map(trades)
      trades.map { |trade| self.new trade }
    end

    attr_reader :timestamp, :amount, :price

    def initialize(trade)
      @timestamp = trade.timestamp
      @amount = trade.amount
      @price = trade.price
    end
  end
end