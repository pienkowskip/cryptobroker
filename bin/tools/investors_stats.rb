#!/usr/bin/env ruby

require 'cryptobroker'
require 'cryptobroker/utility/markdown'
require 'cryptobroker/chart/simple'

app = Cryptobroker.new('../../ovh-config.yml')

chart_max_length = 5000
timestamp_column = Cryptobroker::Model::Trade.arel_table[:timestamp]

Cryptobroker::Model::Investor.enabled.preload(market: [:exchange, :base, :quote]).order(:name).each do |investor|
  puts "# Investor: #{investor.name}", nil

  market = investor.market
  investor.load_classes
  indicator = investor.get_indicator_class.new investor.get_indicator_conf
  puts "* exchange: **#{market.exchange.name}**"
  puts "* market: **#{market.couple}** (id: #{market.id})"
  puts "* beginning: **#{investor.beginning}**"
  puts '* timeframe: **%.1f min**' % (investor.timeframe / 60.0)
  puts "* indicator: **#{indicator.name}**"

  puts nil, '## Last balance changes'
  balances = investor.balances.preload(:trade).last(10).map do |balance|
    row = [balance.base, balance.quote].map { |am| '%.8f' % am }
    row << balance.timestamp
    row << (balance.trade.nil? ? nil : ('%s at %.8f' % [balance.trade.type, balance.trade.price]))
    row
  end
  Cryptobroker::Utility::Markdown.table(balances.reverse, ['base', 'quote', 'timestamp', 'transaction'], Array.new(4, :rjust))

  puts nil, '## Last signals'
  full_tf = ((Time.now - investor.beginning) / investor.timeframe).floor
  till = investor.beginning + investor.timeframe * full_tf
  since = investor.beginning
  since += (full_tf - chart_max_length) * investor.timeframe if full_tf > chart_max_length
  chart = Cryptobroker::Chart::Simple.new(since, investor.timeframe)
  trades = market.trades
               .where(timestamp_column.gteq(since))
               .where(timestamp_column.lteq(till))
               .pluck(*Cryptobroker::Model::LightTrade::ATTRIBUTES)
  trades = Cryptobroker::Model::LightTrade.map(trades)
  trades.each { |trade| chart.append(trade.timestamp, trade.price, trade.amount) }
  chart.finish
  signals = []
  indicator.append(chart.to_a) { |type, timestamp, params| signals.push [type, timestamp, params[:price]] }
  Cryptobroker::Utility::Markdown.table(signals.last(10).reverse, ['signal', 'generated', 'price'], Array.new(3, :rjust))
  puts nil
end
