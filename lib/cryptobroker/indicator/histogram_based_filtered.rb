module Cryptobroker::Indicator
  module HistogramBasedFiltered
    def run(chart)
      @last_sig = nil
      hist = histogram(chart)
      hist.each_cons(3).with_index do |elms,i|
        unless elms.any? &:nil?
          if elms[0] < 0 && elms[1] >= 0 && elms[2] >= 0
            signal :buy, chart[i+2].end, i+2
          elsif elms[0] > 0 && elms[1] <= 0 && elms[2] <= 0
            signal :sell, chart[i+2].end, i+2
          end
        end
      end
    end

    protected

    def signal(type, timestamp, idx)
      return if @last_sig == type
      @last_sig = type
      super
    end
  end
end