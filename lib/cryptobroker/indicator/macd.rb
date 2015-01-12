require_relative './histogram_based'
require_relative './plot'

module Cryptobroker::Indicator
  class MACD
    include HistogramBased

    def initialize(brokers, price = :median, fast = 12, slow = 26, signal = 9)
      super brokers, price
      @macd = Macd.new fast, slow, signal
    end

    def histogram(chart)
      shift_nils @macd.run(price chart)[:out_macd_hist]
    end

    def plot(chart)
      price = price chart
      macd = @macd.run(price)
      Plot.multi chart, [[price, 'lines']], [
                          [shift_nils(macd[:out_macd]), 'lines'],
                          [shift_nils(macd[:out_macd_signal]), 'lines'],
                          [shift_nils(macd[:out_macd_hist]), 'boxes'],
                      ]
    end
  end
end