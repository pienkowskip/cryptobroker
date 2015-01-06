require 'indicator'
require 'gnuplot'

module Cryptobroker::Indicator
  class MACD
    include ::Indicator
    include ::Indicator::AutoGen

    def initialize(brokers, price = :median)
      @brokers = brokers
      @price = price
      @macd = Macd.new 12, 26, 9
    end

    def run(chart)
      hist = shift_nils @macd.run(chart.map { |i| i.send @price })[:out_macd_hist]
      last = nil
      hist.each_with_index do |v,i|
        unless last.nil? || v.nil?
          if last < 0 && v >= 0
            signal :buy, chart[i].end
          elsif last > 0 && v <= 0
            signal :sell, chart[i].end
          end
        end
        last = v
      end
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
    private

    def shift_nils(array)
      ri = array.rindex { |i| !i.nil? }
      return array if ri.nil?
      array.rotate! ri + 1
    end

    def signal(type, timestamp)
      @brokers.each { |broker| broker.send type, timestamp }
    end
  end
end
