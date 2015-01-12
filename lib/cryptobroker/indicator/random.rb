require_relative './base'

module Cryptobroker::Indicator
  class Random
    include Base
    TRANSACTIONS = 0.12

    def run(chart)
      transactions = chart.zip(chart.size.times).shuffle.slice(0, (chart.size * TRANSACTIONS).to_i).sort_by { |i,_| i.start }
      transactions.each_with_index do |v,mod|
          signal mod % 2 == 0 ? :buy : :sell, v[0].start, v[1]
      end
    end
  end
end