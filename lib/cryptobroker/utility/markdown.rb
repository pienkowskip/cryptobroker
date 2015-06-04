require 'set'

module Cryptobroker::Utility
  module Markdown
    def self.table(rows, headers = nil, justify_methods = nil, io = $stdout)
      rows = rows.map { |row| row.map(&:to_s) }
      unless headers.nil?
        headers = headers.map(&:to_s)
        rows.push(headers)
      end
      widths = rows.transpose.map { |col| col.map(&:size).max }
      rows.pop unless headers.nil?

      justify_methods = Array.new(widths.size, :ljust) if justify_methods.nil?
      proper_justify_methods = Set[:rjust, :ljust, :center]
      raise ArgumentError, 'invalid justify methods' unless justify_methods.size == widths.size &&
          justify_methods.all? { |jm| proper_justify_methods.include?(jm) }

      rows = rows.map do |row|
        row.each_with_index.map { |str, ci| ' ' << str.public_send(justify_methods.fetch(ci), widths.fetch(ci)) << ' ' }
      end
      unless headers.nil?
        bar = justify_methods.zip(widths).map do |jm, width|
          (jm == :center || jm == :ljust ? ':' : '-') << '-' * (width) << (jm == :center || jm == :rjust ? ':' : '-')
        end
        rows.unshift(bar)
        rows.unshift(headers.zip(widths).map { |header, width| header.center(width + 2) })
      end
      rows.each { |row| io.puts '|' << row.join('|') << '|' }
    end
  end
end