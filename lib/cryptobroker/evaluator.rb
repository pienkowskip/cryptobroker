require 'forwardable'
require_relative 'evaluator/config'
require_relative 'evaluator/chart_dispatcher'

class Cryptobroker::Evaluator
  extend Forwardable

  def_delegators :@chart_dispatcher, :market_trades_keys, :set_market_trades, :get_market_trades, :delete_market_trades

  def initialize(config_filename)
    @config = Config.new(config_filename)
    @chart_dispatcher = ChartDispatcher.new
  end

end