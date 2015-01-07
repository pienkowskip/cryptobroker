require_relative './cryptobroker/version'
require_relative './cryptobroker/config'
require_relative './cryptobroker/database'
require_relative './cryptobroker/ohlcv'
require_relative './cryptobroker/indicator/macd'
require_relative './cryptobroker/indicator/filtered_macd'
require_relative './cryptobroker/indicator/dema'
require_relative './cryptobroker/broker/basic'

class Cryptobroker
  DELAY_PER_RQ = 3
  RETRIES = 2

  def initialize(config_file = 'config.yml')
    @config = Config.new(config_file)
    Database.init(@config.database[:development])
  end

  def trace
    markets = Market.preload(:exchange, :base, :quote).where(traced: true)
    apis = {}
    markets.each { |market| apis[market.exchange.api] = nil }
    apis.each do |api,_|
      require_relative './cryptobroker/api/' + api
      apis[api] = ('Cryptobroker::API::' + api.camelize).constantize.new(@config.auth[api.to_sym])
    end
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
        Trade.transaction do
          Trade.create(trades.map { |t| t[:market] = market ; t })
        end unless trades.empty?
      end
      delay = rq * DELAY_PER_RQ - (Time.now - start)
      sleep delay if delay > 0
    end
  end

  def trades
    markets = {}
    Market.preload(:base, :quote).where(traced: true).each do |market|
      markets[market.couple] = Trade.unscoped.where(market: market).order(:timestamp).load
    end
    markets
  end

  def ohlcv(period, starts = nil, ends = nil)
    markets = {}
    Market.preload(:base, :quote).where(traced: true).each do |market|
      markets[market.couple] = OHLCV.create Trade.unscoped.where(market: market).order(:timestamp).load, period, starts, ends, false
    end
    markets
  end
end