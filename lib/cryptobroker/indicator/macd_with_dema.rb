require_relative './histogram_based'
require_relative './plot'

module Cryptobroker::Indicator
  class MACDWithDEMA
    include HistogramBased

    def initialize(brokers, price = :median, fast = 12, slow = 26, signal = 9)
      super brokers, price
      @fast = Dema.new fast
      @slow = Dema.new slow
      @signal = Dema.new signal
      @macd = Macd.new fast, slow, signal
    end

    def histogram(chart)
      price = price chart
      fast = shift_nils @fast.run price
      slow = shift_nils @slow.run price
      macd = fast.zip(slow).map { |f,s| f.nil? || s.nil? ? nil : f - s }
      signal = @signal.run macd.drop(macd.index { |i| !i.nil? })
      signal = shift_nils signal.fill(nil, signal.size, price.size - signal.size)
      macd.zip(signal).map { |m,s| m.nil? || s.nil? ? nil : m - s }
    end

    def plot(chart)
      price = price chart
      fast = shift_nils @fast.run price
      slow = shift_nils @slow.run price
      macd = fast.zip(slow).map { |f,s| f.nil? || s.nil? ? nil : f - s }
      signal = @signal.run macd.drop(macd.index { |i| !i.nil? })
      signal = shift_nils signal.fill(nil, signal.size, price.size - signal.size)
      hist = macd.zip(signal).map { |m,s| m.nil? || s.nil? ? nil : m - s }
      Plot.multi chart,
                 [[price, 'lines']],
                 [
                     [shift_nils(macd), 'lines'],
                     [shift_nils(signal), 'lines'],
                     [shift_nils(hist), 'boxes'],
                 ]
    end
  end
end