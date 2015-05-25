require_relative 'simple'

class Cryptobroker::Chart
  class Buffered < Simple
    attr_reader :buffer_size, :total_size

    def initialize(beginning, timeframe, buffer_size)
      raise ArgumentError, 'buffer_size have to be positive' unless buffer_size > 0
      super(beginning, timeframe)
      @buffer_size = buffer_size
      @total_size = 0
    end

    def map_total_index(index)
      index - (@total_size - size)
    end

    def slice_from(idx)
      raise IndexError, 'index outside of buffer bounds' if idx < 0 || idx > size
      self[idx, size - idx]
    end

    protected

    def push(elm)
      @bars.shift until size < @buffer_size
      @total_size += 1
      super
    end
  end
end