require_relative '../utility/statistics'
require_relative '../utility/logging'

class Cryptobroker::Evaluator
  class BaseEvaluator
    extend Cryptobroker::Utility::Statistics
    include Cryptobroker::Utility::Logging

    HOUR_TF = 60 * 60

    def initialize(config, chart_dispatcher)
      @config, @chart_dispatcher = config, chart_dispatcher
    end
  end
end