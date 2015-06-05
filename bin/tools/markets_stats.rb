#!/usr/bin/env ruby

require 'cryptobroker'
require 'cryptobroker/evaluator'

app = Cryptobroker.new('../../dev-config.yml')

markets = app.trades

evaluator = Cryptobroker::Evaluator.new('../../tmp/indicator_test_case.yml')

markets.map! do |market, trades|
  evaluator.set_market_trades(market.id, trades)
  [market.id, market]
end
markets = Hash[markets]

evaluator.market_chart_coverage(evaluator.market_trades_keys) do |key, coverages|
  market = markets[key]

  puts nil, "## Market: #{market.couple} (id: #{market.id})", nil
  last, first = market.trades.last, market.trades.first
  count = market.trades.count
  diff = ->(method) { last.public_send(method) - first.public_send(method) }
  puts "- begins: **#{first.timestamp}**"
  puts "- ends: **#{last.timestamp}**"
  puts '- lasts: **%.1f days**' % (diff.call(:timestamp).to_f / 24 / 3600)

  puts nil, '### Fetching performance'
  puts "- actual trades: **#{count}**"
  puts "- expected trades: **#{diff.call(:tid) + 1}**"
  puts '- ratio: **%.1f%%**' % (count.to_f * 100 / (diff.call(:tid) + 1))

  puts nil, '### Chart coverage per timestamp'
  coverages.each do |tf, actual, expected|
    puts '- %4.1f min: **%4.1f%%** (%d of %.1f)' % [tf / 60.0, actual * 100 / expected, actual, expected]
  end
  puts nil
end
