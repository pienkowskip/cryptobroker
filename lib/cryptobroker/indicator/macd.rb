require_relative './histogram_based'
require 'gnuplot'

module Cryptobroker::Indicator
  class MACD
    include HistogramBased

    def initialize(brokers, price = :median)
      super brokers, price
      @macd = Macd.new 12, 26, 9
    end

    def histogram(chart)
      shift_nils @macd.run(chart.map { |i| i.send @price })[:out_macd_hist]
    end

    def plot(chart)
      s = chart.first.start
      x = chart.map { |i| i.start - s }
      price = chart.map { |i| i.send @price }
      macd = @macd.run(price)

      Gnuplot.open do |gp|
        gp.write "set terminal wxt size 1350,650\n"
        gp.write '
set tmargin 1
set bmargin 1
set lmargin 4
set rmargin 1
unset xtics
'
        gp.write "unset key\n"
        gp.write "set multiplot layout 2, 1\n"
        Gnuplot::Plot.new( gp ) do |plot|
          plot.xrange "[#{x.first}:#{x.last}]"
          plot.data << Gnuplot::DataSet.new( [x, price] ) do |ds|
            ds.with = "lines"
            ds.notitle
          end
        end
        gp.write "unset key\n"
        Gnuplot::Plot.new( gp ) do |plot|
          plot.xrange "[#{x.first}:#{x.last}]"
          add_plot = ->(y, with) do
            y = y.reject {|m|m.nil?}
            plot.data << Gnuplot::DataSet.new( [x.reverse.slice(0, y.size).reverse, y] ) { |ds| ds.with = with }
          end
          add_plot[macd[:out_macd], "lines"]
          add_plot[macd[:out_macd_signal], "lines"]
          add_plot[macd[:out_macd_hist], "boxes"]
        end
        gp.write "unset multiplot\n"
      end
    end
  end
end