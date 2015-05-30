require_relative '../chart/simple'

class Cryptobroker::Evaluator
  class ChartDispatcher
    def initialize
      @trades = {}
      @charts = {}
    end

    def market_trades_keys
      @trades.keys
    end

    def set_market_trades(key, trades)
      array = trades.to_a
      raise ArgumentError, 'empty trades array' if array.empty?
      delete_market_trades(key)
      array = array.dup if array.equal?(trades)
      @trades[key.freeze] = array.freeze
    end

    def get_market_trades(key)
      @trades[key]
    end

    def delete_market_trades(key)
      @charts.delete_if { |chart_key, _| chart_key[0] == key }
      @trades.delete(key)
    end

    def chart(key, timeframe) # What with different beginnings?
      @charts.fetch([key, timeframe].freeze) do |chart_key|
        trades = @trades.fetch(key)
        chart = Cryptobroker::Chart::Simple.new(trades.first.timestamp, timeframe)
        trades.each { |trade| chart.append(trade.timestamp, trade.price, trade.amount) }
        @charts[chart_key] = chart.finish.to_a.freeze
      end
    end
  end
end