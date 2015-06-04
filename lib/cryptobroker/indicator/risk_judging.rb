require_relative 'judging_tool'
require_relative '../broker/relative'

module Cryptobroker::Indicator
  class RiskJudging < JudgingTool
    class Vector
      extend Cryptobroker::Utility::Statistics

      attr_reader :data

      def initialize
        @data = []
      end

      def append(array)
        @data.concat array
        @length = nil
        @mean = nil
      end

      def dim
        @data.size
      end

      def mean
        return @mean unless @mean.nil?
        @mean = self.class.mean @data
      end

      def length
        return @length unless @length.nil?
        @length = self.class.standard_deviation mean, @data
      end

      def correlation(vector)
        raise ArgumentError, 'different dimensions of vectors' if self.dim != vector.dim
        cov = @data.zip(vector.data).map { |u,v| u*v }.reduce(:+)
        cov = cov / self.dim.to_d - self.mean * vector.mean
        cov / (self.length * vector.length)
      end
    end

    CORR_QUALIFIED = 5
    CORR_SHOWN = 10

    def initialize(timeframes, min_sample_bars, transaction_fee)
      super timeframes, min_sample_bars
      @brokers = {}
      @prices.each do |p|
        @brokers[p] = [
            Cryptobroker::Broker::Relative.new(:base, p, transaction_fee),
            Cryptobroker::Broker::Relative.new(:quote, p, transaction_fee)
        ]
      end
    end

    def judge(trades)
      results = {}
      timer = Timer.new
      @timeframes.each do |timeframe|
        timer.start
        samples = []
        trades.each do |trade|
          ts = trade.first.timestamp
          [0, rand(1..(timeframe-1).to_i)].each do |offset|
            chart = ohlcv(trade, timeframe, ts + offset)
            samples << chart if chart.size >= @min_sample_bars
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
            results[[timeframe,price]] = {
                scores: scores,
                correlations: [],
                samples: {count: samples.size, bars: samples_bars}
            }
            next
          end
          timer.start
          @indicators.each do |indicator|
            brokers = @brokers[price]
            indicator = indicator[brokers, price]
            result = {}
            vector = Vector.new
            max_drawdown = 0
            samples.each do |chart|
              brokers.each { |broker| broker.reset chart }
              indicator.run chart
              startup = indicator.startup
              brokers.each do |broker|
                result[broker] = [] unless result.include? broker
                broker_result = broker.results
                vector.append broker_result
                broker_result.shift startup
                dd = drawdown broker_result
                max_drawdown = dd if dd < max_drawdown
                result[broker].concat broker_result
              end
            end
            scores[indicator.name] = {
                mean: self.class.mean(result.values.map { |br| self.class.mean br }),
                vector: vector,
                drawdown: max_drawdown
            }
          end
          timer.finish
          logger.debug { timer.enhance 'Measured performance of %d indicators on %d samples (%d bars).' % [@indicators.size, samples.size, samples_bars] }
          max_name = scores.keys.map { |i| i.length }.max
          list = scores.sort_by { |_,v| v[:mean] }.reverse
          list.each do |name, score|
            percents = [score[:mean], score[:mean] * HOUR_TF / timeframe, score[:drawdown]].map { |p| p * 100 }
            puts "%-#{max_name}s %+.6f%% | %+.4f%%/h | drawdown: %+.4f%%" % ([name] + percents)
          end
          puts "== correlations (top #{CORR_SHOWN} pairs from first #{CORR_QUALIFIED} indicators) =="
          timer.start
          top = list.first(CORR_QUALIFIED).map { |name,score| [name, score[:vector]] }
          scores.values { |score| score.delete :vector }
          correlations = top.combination(2).map do |a,b|
            [a[1].correlation(b[1]), a[0], b[0]]
          end
          timer.finish
          logger.debug { timer.enhance 'Calculated correlations of %d vector pairs in %d-dim space.' % [correlations.size, top.first[1].dim] }
          correlations.sort_by! { |correlation,_,_| correlation }
          correlations.first(CORR_SHOWN).each { |i| puts '%+.4f: %s & %s' % i }
          results[[timeframe,price]] = {
              scores: scores,
              correlations: [],
              samples: {count: samples.size, bars: samples_bars}
          }
        end
      end
      results
    end

    private

    def drawdown(chart)
      max = 0
      last = 0
      sum = 0
      chart.each do |v|
        if v < 0
          sum += v
        else
          if last < 0
            max = sum if sum < max
            sum = 0
          end
        end
        last = v
      end
      max = sum if sum < max
      max
    end
  end
end