require_relative './cryptobroker/version'
require_relative './cryptobroker/config'
require_relative './cryptobroker/database'

class Cryptobroker
  DELAY_PER_RQ = 3
  RETRIES = 2

  def initialize(config_file = 'config.yml')
    @config = Config.new(config_file)
    Database.init(@config.database[:development])
  end

  def trace
    # Exchange.includes(:markets).where(markets: {traced: true})
    markets = Market.preload(:exchange, :base, :quote).where(traced: true)
    apis = {}
    markets.each { |market| apis[market.exchange.api] = nil }
    apis.each do |api,_|
      require_relative './cryptobroker/api/' + api
      apis[api] = ('Cryptobroker::API::' + api.camelize).constantize.new(@config.auth[api.to_sym])
    end
    loop do
      rq = 0
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
      sleep rq * DELAY_PER_RQ
    end
  end
end