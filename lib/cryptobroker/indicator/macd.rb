require_relative 'histogram_based'

module Cryptobroker::Indicator
  class MACD
    include HistogramBased

    def initialize(conf = {price: 'median', fast: 12, slow: 26, signal: 9})
      super conf
      @macd = Macd.new conf[:fast], conf[:slow], conf[:signal]
    end

    def name
      "MACD(#{@macd.slow_period},#{@macd.fast_period},#{@macd.signal_period})"
    end

    def histogram(chart)
      shift_nils @macd.run(price chart)[:out_macd_hist]
    end
  end
end