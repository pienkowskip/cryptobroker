require_relative 'base_evaluator'

class Cryptobroker::Evaluator
  class FinalScoreEvaluator < BaseEvaluator
    def initialize(config, chart_dispatcher, start_amount = 100)
      super(config, chart_dispatcher)
      @start_amount = start_amount
    end

    def evaluate(market_trades_keys)

    end

    def print_results(results)

    end
  end
end