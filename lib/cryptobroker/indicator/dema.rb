require_relative './histogram_based'
require 'gnuplot'

module Cryptobroker::Indicator
  class DEMA
    include HistogramBased

    def initialize(brokers, price = :median, short = 21, long = 55)
      super brokers, price
      @short_dema = Dema.new short
      @long_dema = Dema.new long
    end

    def histogram(chart)
      price = chart.map { |i| i.send @price }
      short = shift_nils @short_dema.run price
      long = shift_nils @long_dema.run price
      short.zip(long).map { |s,l| s.nil? || l.nil? ? nil : s-l }
    end

    def plot(chart)
      price = chart.map { |i| i.send @price }
      short = @short_dema.run price
      long = @long_dema.run price

      1
      s = chart.first.start
      x = chart.map { |i| i.start - s }
      Gnuplot.open do |gp|
        gp.write "set terminal wxt size 1350,650\n"
        gp.write '
unset xtics
'
        Gnuplot::Plot.new( gp ) do |plot|
          plot.xrange "[#{x.first}:#{x.last}]"
          plot.data << Gnuplot::DataSet.new( [x, price] ) do |ds|
            ds.with = "lines"
            ds.notitle
          end
          add_plot = ->(y, with) do
            y = y.reject {|m|m.nil?}
            plot.data << Gnuplot::DataSet.new( [x.reverse.slice(0, y.size).reverse, y] ) { |ds| ds.with = with }
          end
          add_plot[short,'lines']
          add_plot[long,'lines']
        end
      end

    end
  end
end