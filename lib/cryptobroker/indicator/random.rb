require_relative 'base'

module Cryptobroker::Indicator
  class Random
    include Base

    def initialize(conf = {factor: 0.12})
      super conf
      @factor = conf[:factor]
    end

    def reset
      super
      @last = :sell
    end

    def append(bars, &block)
      bars.each do |bar|
        if rand < @factor
          @last = @last == :buy ? :sell : :buy
          signal @last, bar, @finished, &block
        end
        finish
      end
      update_startup 0
    end

    def name
      'Random'
    end
  end
end