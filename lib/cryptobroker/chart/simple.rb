require 'forwardable'
require_relative 'bar'

class Cryptobroker::Chart
  class Simple
    extend Forwardable

    def_delegators :@bars, :size, :each, :map, :[]
    def_delegator :@bars, :dup, :to_a
    attr_reader :timeframe

    def initialize(beginning, timeframe)
      @bars = []
      @timeframe = timeframe
      @last = Cryptobroker::Chart::Bar.new(beginning, @timeframe)
    end

    def append(timestamp, price, amount)
      frozen_check
      raise ArgumentError, 'given timestamp is out of processable range' if timestamp < @last.start
      finish_until timestamp
      @last.append price, amount
    end

    def finish_until(timestamp)
      frozen_check
      while timestamp >= @last.end
        @last.finish
        push @last unless @last.empty?
        @last = Cryptobroker::Chart::Bar.new @last.end, @timeframe
      end
    end

    def finish
      frozen_check
      @last.finish
      push @last unless @last.empty?
      @last = nil
      @bars.freeze
      freeze
    end

    protected

    def push(elm)
      @bars.push elm
    end

    private

    def frozen_check
      raise RuntimeError, "can't modify frozen #{self.class}" if frozen?
    end
  end
end