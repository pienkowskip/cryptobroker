#!/usr/bin/env ruby

require 'cryptobroker'

detector = Cryptobroker.new('../dev-config.yml').cycles_detector
cycles = detector.run

puts nil, "## Timestamp #{Time.now}"

profitable = Set.new
flattened = []

cycles.each_with_index do |cycle, i|
  cycle.each_with_index do |e, ei|
    flattened << [e[:change], cycle.cycle(2).to_a.slice(ei, cycle.size).map { |c| c[:currency] }] unless e[:change].nil?
    profitable << i if !e[:end].nil? && !e[:start].nil? && e[:end] > e[:start]
  end
end

flattened.sort_by! { |i| i[0] }.reverse!

puts nil, '## Top 5 cycles'
flattened.first(5).each { |ch, cycle| puts '* %+7.3f%%: %s' % [ch, cycle.join(' => ')] }

unless profitable.empty?
  puts nil, '## Profitable'
  profitable.each do |i|
    puts nil, "### cycle ##{i}"
    cycles[i].each do |e|
      puts '%s: %.3f => %.3f (%+.1f%%)' % [e[:currency], e[:start] || 0, e[:end] || 0, e[:change] || 0]
    end
  end
end

puts nil