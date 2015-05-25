module Cryptobroker::Model
  class LightTrade
    ATTRIBUTES = [:timestamp, :amount, :price].freeze

    def self.map(trades)
      trades.map do |trade|
        trade.is_a?(Array) ? self.new(*trade) : self.new(trade.timestamp, trade.amount, trade.price)
      end
    end

    attr_reader *ATTRIBUTES

    def initialize(timestamp, amount, price)
      @timestamp, @amount, @price = timestamp, amount, price
    end
  end
end