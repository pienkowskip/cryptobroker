require_relative 'macd'
require_relative 'histogram_based_filtered'

module Cryptobroker::Indicator
  class FilteredMACD < MACD
    include HistogramBasedFiltered
  end
end