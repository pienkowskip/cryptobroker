require_relative './macd'

class Cryptobroker::Indicator::FilteredMACD < Cryptobroker::Indicator::MACD
  def run(chart)
    @last_sig = nil
    hist = shift_nils @macd.run(chart.map { |i| i.send @price })[:out_macd_hist]
    hist.each_cons(3).with_index do |elms,i|
      unless elms.any? &:nil?
        if elms[0] < 0 && elms[1] >= 0 && elms[2] >= 0
          signal :buy, chart[i+2].end, i+2
        elsif elms[0] > 0 && elms[1] <= 0 && elms[2] <= 0
          signal :sell, chart[i+2].end, i+2
        end
      end
    end
    # i = 3
    # while i < hist.size
    #   unless hist[i].nil? || hist[i-1].nil? || hist[i-2].nil? || hist[i-3].nil?
    #     if hist[i-3] < 0 && hist[i-2] < 0 && hist[i-1] >= 0 && hist[i] >= 0
    #       signal :buy, chart[i].end, i
    #     elsif hist[i-3] > 0 && hist[i-2] > 0 && hist[i-1] <= 0 && hist[i] <= 0
    #       signal :sell, chart[i].end, i
    #     end
    #   end
    #   i += 1
    # end
  end

  protected

  def signal(type, timestamp, idx)
    return if @last_sig == type
    @last_sig = type
    super
  end
end