require_relative './cryptobroker/version'
require_relative './cryptobroker/config'
require_relative './cryptobroker/database'
require_relative './cryptobroker/ohlcv'
require_relative './cryptobroker/cycles_detector/detector'

class Cryptobroker
  DELAY_PER_RQ = 3
  RETRIES = 2

  def initialize(config_file = 'config.yml')
    @config = Config.new(config_file)
    Database.init(@config.database[:development])
  end

  def load_apis(markets)
    apis = {}
    markets.each { |market| apis[market.exchange.api] = nil }
    apis.each do |api,_|
      require_relative './cryptobroker/api/' + api
      apis[api] = ('Cryptobroker::API::' + api.camelize).constantize.new(@config.auth[api.to_sym])
    end
    apis
  end

  def trace
    markets = Model::Market.preload(:exchange, :base, :quote).where(traced: true)
    apis = load_apis(markets)
    loop do
      rq = 0
      start = Time.now
      markets.each do |market|
        api = apis[market.exchange.api]
        last = market.trades.select(:tid).last
        last = last.tid unless last.nil?
        last += 1 unless last.nil?
        rt = RETRIES
        trades = []
        begin
          rq += 1
          rt -= 1
          trades = api.trades(last, market.couple)
        rescue
          retry if rt > 0
        end
        Model::Trade.transaction do
          Model::Trade.create(trades.map { |t| t[:market] = market ; t })
        end unless trades.empty?
      end
      delay = rq * DELAY_PER_RQ - (Time.now - start)
      sleep delay if delay > 0
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

  def ohlcv(market_id, period, starts = nil, ends = nil)
    OHLCV.create Model::LightTrade.map(Model::Trade.unscoped.where(market: market_id).order(:timestamp)), period, starts, ends, false
  end
end