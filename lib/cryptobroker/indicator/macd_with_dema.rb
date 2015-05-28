require_relative 'histogram_based'

module Cryptobroker::Indicator
  class MACDWithDEMA
    include HistogramBased

    def initialize(conf = {price: 'median', fast: 12, slow: 26, signal: 9})
      super conf
      @fast = Dema.new conf[:fast]
      @slow = Dema.new conf[:slow]
      @signal = Dema.new conf[:signal]
    end

    def name
      "MACD(#{@slow.time_period},#{@fast.time_period},#{@signal.time_period}) with DEMA"
    end

    def histogram(chart)
      price = price chart
      fast = shift_nils @fast.run(price)
      slow = shift_nils @slow.run(price)
      macd = fast.zip(slow).map { |f,s| f.nil? || s.nil? ? nil : f - s }
      idx = macd.index { |i| !i.nil? }
      signal = []
      signal = @signal.run(macd.drop(idx)) unless idx.nil?
      signal = shift_nils signal.fill(nil, signal.size, price.size - signal.size)
      macd.zip(signal).map { |m,s| m.nil? || s.nil? ? nil : m - s }
    end
  end
end