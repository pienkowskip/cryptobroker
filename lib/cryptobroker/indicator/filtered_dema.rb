require_relative 'dema'
require_relative 'histogram_based_filtered'

module Cryptobroker::Indicator
  class FilteredDEMA < DEMA
    include HistogramBasedFiltered
  end
end