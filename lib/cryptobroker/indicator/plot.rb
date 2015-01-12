require 'gnuplot'

module Cryptobroker::Indicator
  class Plot
    def self.single(chart, plot)
      x = get_x chart
      Gnuplot.open do |gp|
        gp.puts 'set terminal wxt size 1350,650'
        gp.puts 'unset xtics'
        Gnuplot::Plot.new(gp) do |gnuplot|
          gnuplot.xrange "[#{x.first}:#{x.last}]"
          plot.each { |y,with,title| gnuplot.data << data_set(x, y, with, title) }
        end
      end
    end

    def self.multi(chart, *plots)
      x = get_x chart
      Gnuplot.open do |gp|
        gp.puts 'set terminal wxt size 1350,650'
        gp.puts "set multiplot layout #{plots.size}, 1"
        gp.puts(
            'set tmargin 1',
            'set bmargin 1',
            'set lmargin 4',
            'set rmargin 1',
            'unset xtics')
        plots.each do |series|
          gp.puts 'unset key'
          Gnuplot::Plot.new(gp) do |plot|
            plot.xrange "[#{x.first}:#{x.last}]"
            series.each { |y,with| plot.data << data_set(x, y, with) }
          end
        end
        gp.puts 'unset multiplot'
      end
    end

    private

    def self.data_set(x, y, with, title = nil)
      data = x.zip(y)
      data.reject! { |_,yi| yi.nil? }
      Gnuplot::DataSet.new(data.transpose) do |ds|
        ds.with = with
        ds.title = title unless title.nil?
      end
    end

    def self.get_x(chart)
      beg = chart.first.start
      chart.map { |i| i.start - beg }
    end
  end
end