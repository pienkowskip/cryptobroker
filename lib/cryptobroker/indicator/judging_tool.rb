require_relative './macd'
require_relative './macd_with_dema'
require_relative './macd_on_dema'
require_relative './filtered_macd'
require_relative './filtered_macd_with_dema'
require_relative './dema'
require_relative './filtered_dema'
require_relative './random'
require_relative '../broker/transaction_fee'

module Cryptobroker::Indicator
  class JudgingTool
    class Score
      include Comparable
      attr_reader :amount, :transactions

      def initialize(a, t)
        @amount = a
        @transactions = t
      end

      def <=>(other)
        return nil unless other.is_a? Score
        return self.transactions <=> other.transactions if self.amount == other.amount
        other.amount <=> self.amount
      end
    end

    def initialize(start_amount, periods, min_periods, transaction_fee)
      @start_amount = start_amount
      @periods = periods
      # @prices = [:open, :close, :median, :weighted]
      @prices = [:median, :weighted]
      @min_periods = min_periods
      @brokers = []
      @prices.each do |p|
        @brokers << Cryptobroker::Broker::TransactionFee.new(:base, p, transaction_fee)
        @brokers << Cryptobroker::Broker::TransactionFee.new(:quote, p, transaction_fee)
      end
      @indicators = {
          'MACD(12,26,9)' => ->(b, p) { MACD.new b, p, 12, 26, 9 },
          'MACD(5,35,5)' => ->(b, p) { MACD.new b, p, 5, 35, 5 },
          'MACD(13,17,9)' => ->(b, p) { MACD.new b, p, 13, 17, 9 },
          'MACD(12,26,9) filtered' => ->(b, p) { FilteredMACD.new b, p, 12, 26, 9 },
          'MACD(5,35,5) filtered' => ->(b, p) { FilteredMACD.new b, p, 5, 35, 5 },
          'MACD(16,97,2) filtered' => ->(b, p) { FilteredMACD.new b, p, 16, 97, 2 },
          'MACD(13,17,9) filtered' => ->(b, p) { FilteredMACD.new b, p, 13, 17, 9 },
          'DEMA(21,55)' => ->(b, p) { DEMA.new b, p, 21, 55 },
          'DEMA(50,100)' => ->(b, p) { DEMA.new b, p, 50, 100 },
          'DEMA(21,55) filtered' => ->(b, p) { FilteredDEMA.new b, p, 21, 55 },
          'DEMA(50,100) filtered' => ->(b, p) { FilteredDEMA.new b, p, 50, 100 },
          'MACD(12,26,9) with DEMA' => ->(b, p) { MACDWithDEMA.new b, p, 12, 26, 9 },
          'MACD(5,35,5) with DEMA' => ->(b, p) { MACDWithDEMA.new b, p, 5, 35, 5 },
          'MACD(13,17,9) with DEMA' => ->(b, p) { MACDWithDEMA.new b, p, 13, 17, 9 },
          'MACD(12,26,9) with DEMA filtered' => ->(b, p) { FilteredMACDWithDEMA.new b, p, 12, 26, 9 },
          'MACD(5,35,5) with DEMA filtered' => ->(b, p) { FilteredMACDWithDEMA.new b, p, 5, 35, 5 },
          'MACD(13,17,9) with DEMA filtered' => ->(b, p) { FilteredMACDWithDEMA.new b, p, 13, 17, 9 },
          'MACD(16,97,2) with DEMA filtered' => ->(b, p) { FilteredMACDWithDEMA.new b, p, 16, 97, 2 },
          'MACD(12,26,9) on DEMA(8)' => ->(b, p) { MACDOnDEMA.new b, p, 12, 26, 9, 8 },
          'MACD(5,35,5) on DEMA(8)' => ->(b, p) { MACDOnDEMA.new b, p, 5, 35, 5, 8 },
          'MACD(13,17,9) on DEMA(8)' => ->(b, p) { MACDOnDEMA.new b, p, 13, 17, 9, 8 },
          'MACD(16,97,2) on DEMA(8)' => ->(b, p) { MACDOnDEMA.new b, p, 16, 97, 2, 8 },
          'MACD(12,26,9) on DEMA(5)' => ->(b, p) { MACDOnDEMA.new b, p, 12, 26, 9, 5 },
          'MACD(5,35,5) on DEMA(5)' => ->(b, p) { MACDOnDEMA.new b, p, 5, 35, 5, 5 },
          'MACD(13,17,9) on DEMA(5)' => ->(b, p) { MACDOnDEMA.new b, p, 13, 17, 9, 5 },
          'Random' => ->(b, p) { Random.new b, p },
      }
      @prng = ::Random.new
    end

    def judge(trades)
      results = {}
      max_name = @indicators.keys.map { |i| i.length }.max
      @periods.each do |period|
        samples = []
        add_sample = ->(sample) { samples << sample if sample.size >= @min_periods }
        trades.each do |trade|
          ts = trade.first.timestamp
          [0, rand(1..(period-1).to_i), rand(1..(period-1).to_i)].each do |offset|
            chart = ohlcv(trade, period, ts + offset)
            add_sample[chart]
            2.times do
              add_sample[cut_chart(chart, 0.6, 0.7)] if chart.size * 0.7 >= @min_periods
              add_sample[cut_chart(chart, 0.4, 0.5)] if chart.size * 0.5 >= @min_periods
            end
          end
        end
        [:median, :weighted].each do |price|
          puts "\n"
          puts '=== period: %.1fm, samples: %d, price: %s ===' % [period / 60.0, samples.size, price]
          scores = {}
          if samples.empty?
            results[[period,price]] = {scores: scores, samples: samples.size}
            next
          end
          @indicators.each do |name, indicator|
            indicator = indicator[@brokers, price]
            samples_scores = samples.map do |chart|
              @brokers.each { |broker| broker.reset @start_amount, chart }
              indicator.run chart
              result = []
              @brokers.each do |broker|
                po = broker.pay_out
                po = Score.new(po[:amount], po[:transactions] /= chart.size.to_f)
                result << po
                2.times { result << po } if broker.price == price
              end
              # result.sort!
              # Score.new middle(result.map &:amount), middle(result.map &:transactions)
              Score.new mean(result.map &:amount), mean(result.map &:transactions)
            end
            samples_scores.sort!
            amounts = samples_scores.map &:amount
            trs = samples_scores.map &:transactions
            result = {
                median: Score.new(middle(amounts), middle(trs)),
                mean: Score.new(mean(amounts), mean(trs))
            }
            sd = ->(s) { Score.new standard_deviation(s.amount, amounts), standard_deviation(s.transactions, trs) }
            result[:median_sd] = sd[result[:median]]
            result[:mean_sd] = sd[result[:mean]]
            scores[name] = result
          end
          results[[period,price]] = {scores: scores, samples: samples.size}
          [:median, :mean].each do |sym|
            puts "== order by #{sym} =="
            list = scores.sort_by { |_,v| v[sym].amount }
            list.reverse_each do |name, score|
              sc = score[sym]
              sd = score[:"#{sym}_sd"]
              puts "%-#{max_name}s %9.4f (trs: %.3f) [sd: %.5f (trs: %.4f)]" % [name, sc.amount, sc.transactions, sd.amount, sd.transactions]
            end
          end
        end
      end
    end

    private

    def rand(*args)
      @prng.rand *args
    end

    def cut_chart(chart, min, max)
      min = (chart.size * min).to_i
      max = (chart.size * max).to_i
      size = rand(min..max)
      beg = rand(chart.size - size)
      chart.slice(beg, size)
    end

    def ohlcv(trade, period, starts = nil, ends = nil)
      Cryptobroker::OHLCV.create trade, period, starts, ends, false
    end

    def middle(ar)
      ar.size % 2 == 1 ? ar[ar.size/2] : (ar[ar.size/2 - 1] + ar[ar.size/2]) / 2.0
    end

    def median(ar)
      ar.sort!
      middle(ar)
    end

    def mean(ar)
      ar.reduce(:+) / ar.size.to_f
    end

    def standard_deviation(item, ar)
      Math.sqrt(ar.reduce(0) { |accu,i| accu + (i-item)**2 } / ar.size.to_f)
    end
  end
end