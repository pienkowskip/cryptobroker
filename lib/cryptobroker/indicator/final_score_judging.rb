require_relative './judging_tool'
require_relative '../broker/transaction_fee'

module Cryptobroker::Indicator
  class FinalScoreJudging < JudgingTool
    class Score
      include Comparable
      attr_reader :amount, :transactions, :timeframes

      def initialize(a, t, tfs = nil)
        @amount = a
        @transactions = t
        @timeframes = tfs
        unless @timeframes.nil?
          @amount /= @timeframes
          @transactions /= @timeframes
        end
      end

      def <=>(other)
        return nil unless other.is_a? Score
        return self.transactions <=> other.transactions if self.amount == other.amount
        other.amount <=> self.amount
      end
    end

    def initialize(start_amount, timeframes, min_sample_bars, transaction_fee)
      super timeframes, min_sample_bars
      @start_amount = start_amount
      @brokers = {}
      @prices.each do |p|
        @brokers[p] = [
            Cryptobroker::Broker::TransactionFee.new(:base, p, transaction_fee),
            Cryptobroker::Broker::TransactionFee.new(:quote, p, transaction_fee)
        ]
      end
    end

    def judge(trades)
      results = {}
      timer = Timer.new
      @timeframes.each do |timeframe|
        timer.start
        samples = []
        add_sample = ->(sample) { samples << sample if sample.size >= @min_sample_bars }
        trades.each do |trade|
          ts = trade.first.timestamp
          [0, rand(1..(timeframe-1).to_i)].each do |offset|
            chart = ohlcv(trade, timeframe, ts + offset)
            add_sample[chart]
            add_sample[cut_chart(chart, 0.6, 0.7)] if chart.size * 0.7 >= @min_sample_bars
            add_sample[cut_chart(chart, 0.4, 0.5)] if chart.size * 0.5 >= @min_sample_bars
          end
        end
        samples_bars = samples.map { |s| s.size}.reduce(0, :+)
        timer.finish
        logger.debug { timer.enhance 'Created %d samples (%d bars).' % [samples.size, samples_bars] }
        @prices.each do |price|
          puts "\n"
          puts '=== timeframe: %.1fm, samples: %d (%d bars), price: %s ===' % [timeframe / 60.0, samples.size, samples_bars, price]
          scores = {}
          if samples.empty?
            results[[timeframe,price]] = {scores: scores, samples: {count: samples.size, bars: samples_bars}}
            next
          end
          timer.start
          @indicators.each do |indicator|
            brokers = @brokers[price]
            indicator = indicator[brokers, price]
            result = []
            samples.each do |chart|
              brokers.each { |broker| broker.reset @start_amount, chart }
              indicator.run chart
              chart_size = chart.size - indicator.startup
              brokers.each do |broker|
                po = broker.pay_out
                result << Score.new((po[:amount] - @start_amount) / @start_amount, po[:transactions].to_d, chart_size)
              end
            end
            result.sort!
            weights = result.map &:timeframes
            amounts = result.map(&:amount).zip(weights)
            trs = result.map(&:transactions).zip(weights)
            result = {
                median: Score.new(self.class.weighted_middle(amounts), self.class.weighted_middle(trs)),
                mean: Score.new(self.class.weighted_mean(amounts), self.class.weighted_mean(trs))
            }
            sd = ->(s) { Score.new self.class.weighted_standard_deviation(s.amount, amounts), self.class.weighted_standard_deviation(s.transactions, trs) }
            result[:median_sd] = sd[result[:median]]
            result[:mean_sd] = sd[result[:mean]]
            scores[indicator.name] = result
          end
          timer.finish
          logger.debug { timer.enhance 'Measured performance of %d indicators on %d samples (%d bars).' % [@indicators.size, samples.size, samples_bars] }
          results[[timeframe,price]] = {scores: scores, samples: {count: samples.size, bars: samples_bars}}
          max_name = scores.keys.map { |i| i.length }.max
          [:median, :mean].each do |sym|
            puts "== order by #{sym} =="
            list = scores.sort_by { |_,v| v[sym].amount }
            list.reverse_each do |name, score|
              sc = score[sym]
              sd = score[:"#{sym}_sd"]
              puts "%-#{max_name}s %+.6f%% (trs: %4.1f%%) [sd: %.7f%% (trs: %6.3f%%)]" % [name, sc.amount * 100, sc.transactions * 100, sd.amount * 100, sd.transactions * 100]
            end
          end
        end
      end
      results
    end

    private

    def cut_chart(chart, min, max)
      min = (chart.size * min).to_i
      max = (chart.size * max).to_i
      size = rand(min..max)
      beg = rand(chart.size - size)
      chart.slice(beg, size)
    end
  end
end