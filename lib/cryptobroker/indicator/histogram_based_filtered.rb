require_relative 'histogram_based'

module Cryptobroker::Indicator
  module HistogramBasedFiltered
    include HistogramBased

    DEFAULT_FILTER_LENGTH = 1

    def initialize(conf = {filter_length: DEFAULT_FILTER_LENGTH})
      super conf
      @filter_len = conf.fetch :filter_length, DEFAULT_FILTER_LENGTH
    end

    def name
      'filtered ' + super
    end

    def reset
      super
      @awaiting_signal = nil
    end

    protected

    def update_startup(startup)
      super startup.nil? ? nil : startup + @filter_len
    end

    def signal_with_filter(type, _, i)
      if @awaiting_signal.nil?
        @awaiting_signal = [type, i]
      else
        @awaiting_signal = nil if @awaiting_signal[0] != type
      end
    end

    alias_method :signal_without_filter, :signal
    alias_method :signal, :signal_with_filter

    def finish(&block)
      unless @awaiting_signal.nil?
        type, i = @awaiting_signal
        if i + @filter_len <= @finished
          @awaiting_signal = nil
          i = @finished - @buffer_at
          raise IndexError, 'buffer is out of operation range' if i < 0
          signal_without_filter type, @bars_buffer[i], @finished, &block
        end
      end
      super()
    end
  end
end