require 'forwardable'
require_relative 'evaluator/config'
require_relative 'evaluator/chart_dispatcher'
require_relative 'evaluator/final_score_evaluator'

class Cryptobroker::Evaluator
  extend Forwardable

  def_delegators :@chart_dispatcher, :market_trades_keys, :set_market_trades, :get_market_trades, :delete_market_trades
  def_delegator :@final_score, :evaluate, :evaluate_final_score
  def_delegator :@final_score, :print_result, :print_final_score_result

  def initialize(config_filename)
    @config = Config.new(config_filename)
    @chart_dispatcher = ChartDispatcher.new
    @final_score = FinalScoreEvaluator.new(@config, @chart_dispatcher)
  end

  def market_chart_coverage(market_trades_keys)
    market_trades_keys = [*market_trades_keys]
    return enum_for(:market_chart_coverage, market_trades_keys) unless block_given?
    market_trades_keys.each do |key|
      coverages = @config.timeframes.map do |timeframe|
        trades = get_market_trades(key)
        coverage = @chart_dispatcher.chart(key, timeframe).size.to_f
        coverage /= (trades.last.timestamp - trades.first.timestamp) / timeframe.to_f
        [timeframe, coverage]
      end
      yield key, coverages
    end
  end

end