require_relative 'histogram_based'

module Cryptobroker::Indicator
  class MACDOnDEMA
    include HistogramBased

    def initialize(brokers, price = :median, fast = 12, slow = 26, signal = 9, dema = 8)
      super brokers, price
      @macd = Macd.new fast, slow, signal
      @dema = Dema.new dema
    end

    def name
      "MACD(#{@macd.slow_period},#{@macd.fast_period},#{@macd.signal_period}) on DEMA(#{@dema.time_period})"
    end

    def histogram(chart)
      price = price chart
      price = @dema.run price
      price.pop(price.size - price.rindex { |i| !i.nil? } - 1)
      hist = @macd.run(price)[:out_macd_hist]
      hist.fill(nil, hist.size, chart.size - hist.size)
      shift_nils hist
    end
  end
end