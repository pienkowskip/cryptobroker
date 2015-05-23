require_relative 'histogram_based'

module Cryptobroker::Indicator
  class DEMA
    include HistogramBased

    def initialize(conf = {price: 'median', short: 21, long: 55})
      super conf
      @short_dema = Dema.new conf[:short]
      @long_dema = Dema.new conf[:long]
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
  end
end