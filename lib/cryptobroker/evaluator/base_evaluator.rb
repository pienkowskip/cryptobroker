require_relative '../statistics'
require_relative '../logging'

class Cryptobroker::Evaluator
  class BaseEvaluator
    extend Cryptobroker::Statistics
    include Cryptobroker::Logging

    HOUR_TF = 60 * 60

    def initialize(config, chart_dispatcher)
      @config, @chart_dispatcher = config, chart_dispatcher
    end
  end
end