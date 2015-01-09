require_relative './base'

module Cryptobroker::Indicator
  module HistogramBased
    include Base

    def run(chart)
      hist = histogram(chart)
      last = nil
      hist.each_with_index do |v,i|
        unless last.nil? || v.nil?
          if last < 0 && v >= 0
            signal :buy, chart[i].end, i
          elsif last > 0 && v <= 0
            signal :sell, chart[i].end, i
          end
        end
        last = v
      end
    end
  end
end