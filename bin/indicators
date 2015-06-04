#!/usr/bin/env ruby

require 'cryptobroker'
require 'cryptobroker/evaluator'

app = Cryptobroker.new('../dev-config.yml')

markets = app.trades([1, 3, 6, 7])

evaluator = Cryptobroker::Evaluator.new('../tmp/indicators_basic_test.yml')

markets.each { |market, trades| evaluator.set_market_trades(market.id, trades) }

overall_scores = evaluator.final_score_evaluator.evaluate(
    evaluator.market_trades_keys,
    &evaluator.final_score_evaluator.method(:print_timestamp_scores))

evaluator.final_score_evaluator.print_overall_scores(overall_scores, 30)

markets_map = markets.map { |market,_| [market.id, market.couple] }

single_scores = {}
markets_map.each do |market_id, _|
  scores = evaluator.final_score_evaluator.evaluate(market_id) {}
  scores.each do |indicator, score|
    indicator_hash = single_scores.fetch(indicator) { |key| single_scores[key] = {} }
    indicator_hash[market_id] = score
  end
end

puts nil, '# overall indicators scores combined with single markets'
headers = ['pos', 'tf', 'indicator', 'price', 'all markets']
justify_methods = [:rjust, :rjust, :center, :center, :rjust]
format_strs = ['#%02d', '%.1f', '%s', '%s', '%+.4f%% (sd: %.5f%%)']
markets_map.each do |_, couple|
  headers << couple
  justify_methods << :rjust
  format_strs << '%+.4f%% (sd: %.5f%%)'
end
evaluator.final_score_evaluator.send(:print_scores, overall_scores, headers, justify_methods, 30) do |indicator, overall_score, order_by, pos|
  timeframe = indicator.fetch(:timeframe)
  amount_factor = 100 * 24 * 60 * 60 / timeframe.to_d
  results = []
  append_score = ->(score) do
    results << (score.nil? ? nil : [score.fetch(order_by).amount * amount_factor, score.fetch(:"#{order_by}_sd").amount * amount_factor])
  end
  append_score.call(overall_score)
  indicator_single_scores = single_scores.fetch(indicator)
  markets_map.each { |market_id, _| append_score.call(indicator_single_scores[market_id]) }
  results = [pos, timeframe / 60.0, indicator.fetch(:name), indicator.fetch(:config).fetch(:price)].concat(results)
  format_strs.zip(results).map { |format, data| data.nil? ? 'n/a' : (format % data) }
end