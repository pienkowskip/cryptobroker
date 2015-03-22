require 'indicator'

module Cryptobroker::Indicator
  module Base
    include ::Indicator
    include ::Indicator::AutoGen

    attr_reader :startup, :finished

    def initialize(conf = {price: 'median'})
      @price = conf.fetch :price, 'median'
      @price = @price.to_sym rescue @price
      reset
    end

    def name
      'Base'
    end

    def reset
      @finished = 0
      @startup = nil
    end

    protected

    def finish
      @finished += 1
    end

    def signal(type, bar, i)
      yield type, bar.end, {idx: i, price: bar.send(@price)}
    end

    def price(chart)
      chart.map { |i| i.send @price }
    end

    def shift_nils(array)
      ri = array.rindex { |i| !i.nil? }
      return array if ri.nil?
      array.rotate! ri + 1
    end

    def update_startup(startup)
      @startup = startup unless startup.nil?
    end
  end
end