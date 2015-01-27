require 'logger'

module Cryptobroker::Logging
  class Timer
    SIMPLE_FORMAT = '%<msg>s (in %<time>.3fs)'
    COLOR_FORMAT = "\e[1m\e[36m[%<time>.3fs]\e[0m %<msg>s"
    attr_reader :duration

    def start
      raise RuntimeError, 'Timer not finished' unless @start.nil?
      @duration = nil
      @start = Time.now
      self
    end

    def finish
      raise RuntimeError, 'Timer not started' if @start.nil?
      @duration = Time.now - @start
      @start = nil
      self
    end

    def enhance(msg, color = true)
      raise RuntimeError, 'Timer not finished' if @duration.nil?
      (color ? COLOR_FORMAT : SIMPLE_FORMAT) % {msg: msg.to_s, time: @duration}
    end
  end

  def logger
    return @logger unless @logger.nil?
    @logger = Cryptobroker::Logging.logger_for(self.class.name)
  end

  @loggers = {}

  def self.logger_for(classname)
    return @loggers[classname] if @loggers.include? classname
    logger = Logger.new(STDOUT)
    logger.progname = classname
    logger.level = Logger::DEBUG
    @loggers[classname] = logger
  end
end