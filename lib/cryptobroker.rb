require_relative 'illegal_state_error'
require_relative 'cryptobroker/version'
require_relative 'cryptobroker/config'
require_relative 'cryptobroker/database'
require_relative 'cryptobroker/downloader'
require_relative 'cryptobroker/chart'
require_relative 'cryptobroker/investor'
require_relative 'cryptobroker/cycles_detector/detector'
require_relative 'cryptobroker/utility/logging'

class Cryptobroker
  include Utility::Logging

  TRACE_REFRESH_INTERVAL = 10 * 60

  attr_reader :tracer

  def initialize(config_filename = 'config.yml')
    @config = Config.new(config_filename)
    Database.init(@config.database)
    @apis = {}
    @charts = {}
    @investors = []
  end

  def api(exchange)
    return @apis[exchange.name] if @apis.include? exchange.name
    exchange.load_api_class
    @apis[exchange.name] = exchange.get_api_class.new @config.auth.fetch(exchange.name.to_sym)
  end

  def api_by_name(exchange_name)
    return @apis[exchange_name] if @apis.include? exchange_name
    ActiveRecord::Base.with_connection { api Cryptobroker::Model::Exchange.find_by_name!(exchange_name) }
  end

  def downloader(preload_market_ids = [], thread_pool_size = 3)
    return @downloader unless @downloader.nil?
    @downloader = Downloader.new ->(exchange) { api exchange }, thread_pool_size, preload_market_ids
  end

  def charts
    @charts.dup
  end

  def investors
    @investors.dup
  end

  def invest
    raise IllegalStateError, 'already started investing' unless @investors.empty?
    @investors = ActiveRecord::Base.with_connection { Model::Investor.preload(market: [:exchange, :base, :quote]).enabled.to_a }
    return nil if @investors.empty?
    markets = @investors.map(&:market_id).uniq
    downloader = downloader(markets)
    @investors.map! do |investor|
      key = [investor.market_id, investor.beginning, investor.timeframe].freeze
      @charts[key] = Chart.new downloader, *key unless @charts.include? key
      investor.load_classes
      indicator = investor.get_indicator_class.new investor.get_indicator_conf
      broker = investor.get_broker_class.new investor.get_broker_conf, api(investor.market.exchange), investor
      Investor.new @charts[key], indicator, broker, investor.name
    end
    logger.info { 'Cryptobroker started investing with [%d] investors.' % @investors.size }
    investors
  end

  def trace(refresh_interval = TRACE_REFRESH_INTERVAL)
    raise IllegalStateError, 'already started tracing' unless @tracer.nil?
    markets = ActiveRecord::Base.with_connection { Model::Market.where(traced: true).pluck(:id) }
    return nil if markets.empty?
    downloader = downloader(markets)
    @tracer = Thread.new do
      loop do
        markets.each { |id| downloader.request_update id }
        sleep refresh_interval
      end
    end
    @tracer.abort_on_exception = true
    logger.info { 'Cryptobroker started tracing for [%d] markets.' % markets.size }
    @tracer
  end

  def trades(market_ids = nil, since = nil, till = nil)
    ActiveRecord::Base.with_connection do
      markets = Model::Market.preload(:base, :quote)
      markets = market_ids.nil? ? markets.where(traced: true) : markets.where(id: [*market_ids])
      timestamp_column = Cryptobroker::Model::Trade.arel_table[:timestamp]
      markets.map do |market|
        trades = market.trades
        trades = trades.where(timestamp_column.gteq(since)) unless since.nil?
        trades = trades.where(timestamp_column.lteq(till)) unless till.nil?
        trades = trades.pluck(*Cryptobroker::Model::LightTrade::ATTRIBUTES)
        [market, Cryptobroker::Model::LightTrade.map(trades)]
      end
    end
  end

  def cycles_detector
    markets = Model::Exchange.first.markets.preload(:base, :quote)
    CyclesDetector::Detector.new(markets, ->(name) { api name })
  end

  def terminate
    @investors.each &:terminate
    @investors = []
    @charts.values.each &:terminate
    @charts = {}
    unless @tracer.nil?
      @tracer.terminate.join
      @tracer = nil
    end
    unless @downloader.nil?
      @downloader.abort
      @downloader = nil
    end
    logger.info { 'Cryptobroker terminated.' }
  end
end