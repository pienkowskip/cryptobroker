require 'thread'
require 'monitor'
require_relative 'logging'
require_relative 'api/error'

class Cryptobroker::Downloader
  class Market
    include Cryptobroker::Logging

    ATTEMPTS = 2
    RETRY_DELAY = 3

    def initialize(record, api)
      @record = record
      @api = api
      @updated = nil
      @charts = []
      @mutex = Mutex.new
    end

    def update
      return false unless @mutex.try_lock
      last = ActiveRecord::Base.with_connection do
        logger.debug { 'Updating trades of [%s] market of [%s] exchange.' % [@record.couple, @record.exchange.name] }
        trade = @record.trades.tid_ordered.select(:tid).last
        trade.nil? ? nil : trade.tid + 1
      end
      attempts = ATTEMPTS
      trades = nil
      begin
        attempts -= 1
        timestamp = Time.now
        trades = @api.trades @record.couple, last
      rescue Cryptobroker::API::RecoverableError => error
        if attempts > 0
          sleep RETRY_DELAY
          retry
        end
        logger.error { ActiveRecord::Base.with_connection {
          'Fetching trades from [%s] market of [%s] exchange ended in failure after %d attempts. Exception: %s (%s).' %
              [@record.couple, @record.exchange.name, ATTEMPTS, error.message, error.class]
        }}
      end
      if trades.nil?
        @mutex.unlock
        return true
      end
      unless trades.empty?
        ActiveRecord::Base.with_connection do
          Cryptobroker::Model::Trade.transaction do
            trades.map! do |trade|
              trade = trade.to_hash
              trade[:market] = @record
              trade
            end
            trades = Cryptobroker::Model::Trade.create! trades
          end
          trades = Cryptobroker::Model::LightTrade.map(trades)
          logger.info { '%d trades fetched from [%s] market of [%s] exchange and inserted to database.' % [trades.size, @record.couple, @record.exchange.name] }
        end
        trades.sort_by! { |t| t.timestamp }
      end
      @charts.each { |chart| notice chart, trades, timestamp }
      @mutex.unlock
      true
    end

    def register_chart(chart)
      @mutex.synchronize do
        @charts << chart
        trades = ActiveRecord::Base.with_connection do
          query = @record.trades.where Cryptobroker::Model::Trade.arel_table[:timestamp].gteq(chart.beginning)
          #TODO: try to use pluck
          Cryptobroker::Model::LightTrade.map(query)
        end
        notice chart, trades, trades.last.timestamp - 0.1 unless trades.empty?
      end
    end

    private

    def notice(chart, trades, updated)
      trades = trades.reject { |t| t.timestamp < chart.beginning }
      chart.notice trades, updated
    end
  end

  include MonitorMixin
  include Cryptobroker::Logging

  def initialize(api_dispatcher, threads, preload_market_ids = [])
    super()
    @markets = {}
    @api_dispatcher = api_dispatcher
    synchronize do
      ActiveRecord::Base.with_connection do
        Cryptobroker::Model::Market.preload(:exchange, :base, :quote).find(preload_market_ids).each do |market|
          @markets[market.id] = create_market market
        end
      end
    end unless preload_market_ids.empty?
    @queue = Queue.new
    @pool = threads.times.map do
      th = Thread.new do
        loop do
          market_id = @queue.pop
          @queue.push market_id unless market(market_id).update
        end
      end
      th.abort_on_exception = true
      th
    end
    logger.debug { 'Trades downloader with [%d] pooled threads started.' % threads }
  end

  def register_chart(chart, market_id)
    market(market_id).register_chart(chart)
  end

  def request_update(market_id)
    @queue.push market_id
  end

  def abort
    @pool.each(&:terminate).each(&:join)
    logger.debug { 'Trades downloader aborted.' }
  end

  private

  def create_market(record)
    Market.new record, @api_dispatcher[record.exchange]
  end

  def market(id)
    synchronize do
      ActiveRecord::Base.with_connection do
        @markets[id] = create_market Cryptobroker::Model::Market.preload(:exchange, :base, :quote).find(id)
      end unless @markets.include? id
      @markets[id]
    end
  end
end