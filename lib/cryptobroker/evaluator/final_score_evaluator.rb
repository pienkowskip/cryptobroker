require 'set'
require_relative 'base_evaluator'
require_relative '../broker/backtesting/transaction_fee'
require_relative '../utility/markdown'

class Cryptobroker::Evaluator
  class FinalScoreEvaluator < BaseEvaluator
    class Score
      include Comparable
      attr_reader :amount, :transactions, :weight

      def initialize(amount, transactions, weight = nil, divider = nil)
        @amount, @transactions, @weight = amount, transactions, weight
        unless divider.nil?
          @amount /= divider
          @transactions /= divider
        end
      end

      def <=>(other)
        return nil unless other.is_a? Score
        return self.transactions <=> other.transactions if self.amount == other.amount
        other.amount <=> self.amount
      end
    end

    def initialize(config, chart_dispatcher, start_amount = 100)
      super(config, chart_dispatcher)
      @start_amount = start_amount.to_d
      @brokers = {}
      @config.prices.each do |price|
        @brokers[price] = [
            Cryptobroker::Broker::Backtesting::TransactionFee.new(:base, price, @start_amount, @config.transaction_fee),
            Cryptobroker::Broker::Backtesting::TransactionFee.new(:quote, price, @start_amount, @config.transaction_fee)]
      end
    end

    def evaluate(market_trades_keys)
      market_trades_keys = [*market_trades_keys]
      return enum_for(:evaluate, market_trades_keys) unless block_given?

      overall_scores = []
      timer = Timer.new
      @config.timeframes.each do |timeframe|
        timer.start
        samples = []
        market_trades_keys.each do |key|
          samples.concat(prepare_chart_samples(@chart_dispatcher.chart(key, timeframe)).to_a)
        end
        samples_stat = {count: samples.size}
        samples_stat[:bars] = samples.map { |sample, _| sample.size }.reduce(0, :+)
        timer.finish
        logger.debug { timer.enhance 'Created %d samples (%d bars).' % [samples_stat[:count], samples_stat[:bars]] }

        scores = []
        if samples.empty?
          yield scores, timeframe, samples_stat
          next
        end
        timer.start
        indicators = @config.indicators.product(@config.prices)
        indicators.each do |indicator, price|
          ind_class, ind_config = indicator
          ind_config = ind_config.merge(price: price)
          indicator = ind_class.new(ind_config)
          brokers = @brokers[price]
          indicator_score = []
          samples.each do |bars, weight|
            brokers.each { |broker| broker.reset(bars) }
            indicator.append(bars) do |signal, _, params|
              next unless params.fetch(:idx) + 1 < bars.size
              brokers.each { |broker| broker.public_send(signal, params.fetch(:idx) + 1) }
            end
            bars_involved = bars.size - indicator.startup
            indicator.reset
            brokers.each do |broker|
              amount, transactions = broker.result
              indicator_score << Score.new(
                  amount / broker.start_amount - 1,
                  transactions.to_d,
                  weight * bars_involved,
                  bars_involved)
            end
          end

          indicator_score.sort!
          weights = indicator_score.map(&:weight)
          amounts = indicator_score.map(&:amount).zip(weights)
          transactions = indicator_score.map(&:transactions).zip(weights)
          indicator_score = {
              median: Score.new(self.class.weighted_middle(amounts), self.class.weighted_middle(transactions)),
              mean: Score.new(self.class.weighted_mean(amounts), self.class.weighted_mean(transactions))
          }
          indicator_score.to_a.each do |key, score|
            indicator_score[:"#{key}_sd"] = Score.new(
                self.class.weighted_standard_deviation(score.amount, amounts),
                self.class.weighted_standard_deviation(score.transactions, transactions))
          end
          indicator_score = [{name: indicator.name, class: ind_class, config: ind_config, timeframe: timeframe}, indicator_score]
          scores << indicator_score
          overall_scores << indicator_score
        end
        timer.finish
        logger.debug { timer.enhance 'Measured performance of %d indicators on %d samples (%d bars).' % [indicators.size, samples_stat[:count], samples_stat[:bars]] }
        yield scores, timeframe, samples_stat
      end
      overall_scores
    end

    def print_timestamp_scores(scores, timeframe, samples, top_scores = 10, io = $stdout)
      io.puts nil, '# timeframe: %.1f min, samples: %d (%d bars)' % [timeframe / 60.0, samples[:count], samples[:bars]]
      day_factor = 24 * 60 * 60 / timeframe.to_d
      headers = ['pos', 'indicator', 'price', 'change per day', 'trs per day', 'change per bar', 'trs per bar']
      justify_methods = [:rjust, :center, :center, :rjust, :rjust, :rjust, :rjust]
      format_strs = ['#%02d', '%s', '%s', '%+.4f%% (sd: %.5f%%)', '%.2f (sd: %.3f)', '%+.5f%% (sd: %.6f%%)', '%.3f (sd: %.4f)']
      print_scores(scores, headers, justify_methods, top_scores, io) do |indicator, score, order_by, pos|
        sc = score.fetch(order_by)
        sd = score.fetch(:"#{order_by}_sd")
        results = [sc.amount * 100, sd.amount * 100, sc.transactions, sd.transactions]
        results = results.map { |result| result * day_factor }.concat(results)
        results = results.each_slice(2).to_a
        results = [pos, indicator.fetch(:name), indicator.fetch(:config).fetch(:price)].concat(results)
        format_strs.zip(results).map { |format, data| format % data }
      end
    end

    def print_overall_scores(scores, top_scores = 20, io = $stdout)
      io.puts nil, '# overall indicators scores'
      headers = ['pos', 'tf', 'indicator', 'price', 'change per day', 'trs per day']
      justify_methods = [:rjust, :rjust, :center, :center, :rjust, :rjust]
      format_strs = ['#%02d', '%.1f', '%s', '%s', '%+.5f%% (sd: %.6f%%)', '%.3f (sd: %.4f)']
      print_scores(scores, headers, justify_methods, top_scores, io) do |indicator, score, order_by, pos|
        sc = score.fetch(order_by)
        sd = score.fetch(:"#{order_by}_sd")
        timeframe = indicator.fetch(:timeframe)
        day_factor = 24 * 60 * 60 / timeframe.to_d
        results = [sc.amount * 100, sd.amount * 100, sc.transactions, sd.transactions]
        results = results.map { |result| result * day_factor }.each_slice(2).to_a
        results = [pos, timeframe / 60.0, indicator.fetch(:name), indicator.fetch(:config).fetch(:price)].concat(results)
        format_strs.zip(results).map { |format, data| format % data }
      end
    end

    private

    def print_scores(scores, columns_headers, justify_methods, top_scores, io = $stdout)
      top_scores = Integer(top_scores) unless top_scores.nil?
      if scores.empty?
        io.puts nil, '## no scores', nil
        io.flush
        return
      end
      [:median, :mean].each do |order_by|
        io.puts nil, '## %s by %s' % [top_scores.nil? ? 'all' : "top #{top_scores}", order_by], nil
        list = scores.sort_by { |indicator, score| score.fetch(order_by).amount / indicator.fetch(:timeframe).to_d }
        list.reverse!
        list = list.first(top_scores) unless top_scores.nil?
        list = list.map.with_index(1) { |score, pos| yield *score, order_by, pos }
        Cryptobroker::Utility::Markdown.table(list, columns_headers, justify_methods, io)
      end
      io.puts nil
      io.flush
    end

    def prepare_chart_samples(bars)
      return enum_for(:prepare_chart_samples, bars) unless block_given?
      levels = []
      div = bars.size / @config.min_sample_size
      while div > 0
        levels << div
        div /= 2
      end
      return 0 if levels.empty?
      levels.reverse!
      weight = 1.to_d / levels.size
      yield bars, weight
      weight /= 2
      levels.shift
      levels.each do |divider|
        slice_size = bars.size / divider
        [bars, bars.slice(slice_size / 2, bars.size - slice_size)].each do |shift|
          slices = shift.each_slice(slice_size).to_a
          if slices.last.size < slice_size
            incomplete = slices.pop
            slices.last.concat(incomplete)
          end
          slices.each { |slice| yield slice, weight }
        end
      end
      levels.size + 1
    end
  end
end