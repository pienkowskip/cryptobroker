require_relative 'base'

module Cryptobroker::Indicator
  module HistogramBased
    include Base

    DEFAULT_BUFFER_SIZE = 4096

    def initialize(conf = {buffer_size: DEFAULT_BUFFER_SIZE})
      super conf
      @buffer_size = conf.fetch :buffer_size, DEFAULT_BUFFER_SIZE
    end

    def reset
      super
      @buffer_at = 0
      @bars_buffer = []
      @hist_buffer = []
    end

    def append(bars, &block)
      @bars_buffer.concat bars
      @hist_buffer.concat histogram(@bars_buffer).last(bars.size)
      raise IndexError, 'buffer arrays inconsistency' unless @bars_buffer.size == @hist_buffer.size
      run &block
      trim = @bars_buffer.size - @buffer_size
      return if trim < 1
      @bars_buffer.shift trim
      @hist_buffer.shift trim
      @buffer_at += trim
    end

    protected

    def run(&block)
      i = @finished - @buffer_at
      raise IndexError, 'buffer is out of operation range' if i < 0 || (i < 1 && @buffer_at > 0)
      last = i < 1 ? nil : @hist_buffer[i-1]
      startup = nil
      while @finished < @bars_buffer.size + @buffer_at
        curr = @hist_buffer[i]
        unless last.nil? || curr.nil?
          startup = i if startup.nil?
          if last < 0 && curr >= 0
            signal_at :buy, i, &block
          elsif last > 0 && curr <= 0
            signal_at :sell, i, &block
          end
        end
        finish &block
        i += 1
        last = curr
      end
      update_startup startup
    end

    private

    def signal_at(type, i, &block)
      signal type, @bars_buffer[i], @buffer_at + i, &block
    end
  end
end