require_relative 'macd_with_dema'
require_relative 'histogram_based_filtered'

module Cryptobroker::Indicator
  class FilteredMACDWithDEMA < MACDWithDEMA
    include HistogramBasedFiltered
  end
end