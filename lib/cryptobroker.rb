require_relative 'cryptobroker/version'
require_relative 'cryptobroker/config'
require_relative 'cryptobroker/database'
require_relative 'cryptobroker/downloader'
require_relative 'cryptobroker/chart'
require_relative 'cryptobroker/investor'
require_relative 'cryptobroker/cycles_detector/detector'
require_relative 'cryptobroker/logging'

class Cryptobroker
  include Logging
  DELAY_PER_MARKET = 8
  RETRIES = 2

  def initialize(config_file = 'config.yml')
    @config = Config.new(config_file)
    Database.init(@config.database[:development])
    @apis = {}
  end

  def load_apis(markets)
    apis = {}
    markets.map { |m| m.exchange.api }.uniq.each { |n| apis[n] = api n }
    apis
  end

  def api(name)
    return @apis[name] if @apis.include? name
    require_relative 'cryptobroker/api/' + name
    @apis[name] = ('Cryptobroker::API::' + name.camelize).constantize.new(@config.auth[name.to_sym])
  end

  def invest
    investors = ActiveRecord::Base.with_connection { Model::Investor.preload(market: [:exchange, :base, :quote]).enabled.to_a }
    markets = investors.map(&:market_id).uniq
    downloader = Downloader.new ->(name) { api name }, 5, markets
    charts = {}
    investors.map! do |investor|
      key = [investor.market_id, investor.beginning, investor.timeframe]
      charts[key] = Chart.new downloader, *key unless charts.include? key
      investor.load_classes
      indicator = investor.get_indicator_class.new investor.get_indicator_conf
      broker = investor.get_broker_class.new investor, investor.get_broker_conf
      Investor.new charts[key], indicator, broker
    end
    loop do
      # markets.each { |id| downloader.request_update id }
      sleep markets.size * DELAY_PER_MARKET
    end
  rescue StandardError => e
    logger.fatal { "Uncaught exception: #{e.message} (#{e.class})" }
    raise e
  end

  def trace
    markets = ActiveRecord::Base.with_connection { Model::Market.where(traced: true).pluck(:id) }
    downloader = Downloader.new ->(name) { api name }, 5, markets
    loop do
      markets.each { |id| downloader.request_update id }
      sleep markets.size * DELAY_PER_MARKET
    end
  end

  def cycles
    markets = Model::Exchange.first.markets.preload(:base, :quote)
    detector = CyclesDetector::Detector.new markets, load_apis(markets)
    detector.start
  end

  def trades
    markets = {}
    Model::Market.preload(:base, :quote).where(traced: true).each do |market|
      markets[market.couple] = Model::LightTrade.map Model::Trade.unscoped.where(market: market).order(:timestamp)
    end
    markets
  end
end