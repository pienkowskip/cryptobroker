require_relative 'graph'
require_relative 'balance_log'
require_relative 'market_orders'
require_relative '../logging'

module Cryptobroker::CyclesDetector
  class Detector
    include Cryptobroker::Logging

    def initialize(markets, apis)
      currencies = {}
      add_curr = ->(curr) { currencies[curr.id] = curr unless currencies.include? curr.id}
      markets.each { |market| add_curr[market.base] ; add_curr[market.quote] }
      graph = Graph.new
      currencies.values.each { |curr| graph.add_vertex curr }
      markets_hash = {}
      markets.each do |market|
        graph.add_edge market
        markets_hash[[market.base_id, market.quote_id]] = [market, :base_quote]
        markets_hash[[market.quote_id, market.base_id]] = [market, :quote_base]
      end
      @markets = {}

      @cycles = graph.detect_cycles
      map_cycle = ->(cycle) do
        new_cycle = []
        cycle.each_cons(2) do |b,e|
          new_cycle << BalanceLog.new(currencies[b.id])
          market, dir = markets_hash[[b.id, e.id]]
          @markets[market.id] = MarketOrders.new market, apis[market.exchange.api] unless @markets.include? market.id
          new_cycle << [@markets[market.id], dir]
        end
        new_cycle
      end
      new_cycles = []
      @cycles.each do |cycle|
        cycle = cycle + [cycle.first]
        new_cycles << map_cycle[cycle]
        new_cycles << map_cycle[cycle.reverse]
      end
      @cycles = new_cycles
    end

    def start
      timer = Timer.new.start
      @markets.values.map do |market|
        Thread.new { market.update }
      end.each &:join
      timer.finish
      logger.debug { timer.enhance "Updated #{@markets.size} markets." }

      timer.start
      start = {
          'USD' => 10,
          'EUR' => 10,
          'BTC' => 0.05,
          'LTC' => 10,
      }

      @cycles.each do |cycle|
        cycle = cycle.cycle(2).to_a
        cycle[0].add start.fetch(cycle[0].currency.code, 100)
        i = 0
        while i + 2 < cycle.size do
          amount = cycle[i].last
          market, dir = cycle[i+1]
          begin
            if dir == :base_quote
              amount = market.instant_fake_sell amount
            else
              amount = market.instant_fake_buy amount
            end
          rescue
            break
          end
          cycle[i+2].add amount
          i += 2
        end
      end
      timer.finish
      logger.debug { timer.enhance "Checked #{@cycles.size} cycles." }

      @cycles.map do |cycle|
        result = []
        cycle.each_slice(2) do |log,_|
          spent,e = log.log
          p = nil
          p = (e / spent - 1.0) * 100 unless spent.nil? || e.nil?
          result << {
              currency: log.currency.code,
              start: spent,
              end: e,
              change: p
          }
        end
        result
      end
    end
  end
end