require_relative './histogram_based'
require_relative './plot'

module Cryptobroker::Indicator
  class DEMA
    include HistogramBased

    def initialize(brokers, price = :median, short = 21, long = 55)
      super brokers, price
      @short_dema = Dema.new short
      @long_dema = Dema.new long
    end

    def name
      "DEMA(#{@short_dema.time_period},#{@long_dema.time_period})"
    end

    def histogram(chart)
      price = price chart
      short = shift_nils @short_dema.run price
      long = shift_nils @long_dema.run price
      short.zip(long).map { |s,l| s.nil? || l.nil? ? nil : s-l }
    end

    def plot(chart)
      price = price chart
      short = shift_nils @short_dema.run price
      long = shift_nils @long_dema.run price
      Plot.single chart, [
                           [price, 'lines', 'price'],
                           [short, 'lines', 'short DEMA'],
                           [long, 'lines', 'long DEMA']
                       ]
    end
  end
end