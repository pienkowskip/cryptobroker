module Cryptobroker::CyclesDetector
  class BalanceLog
    attr_reader :currency, :log
    def initialize(currency)
      @currency = currency
      @log = []
    end

    def add(amount)
      @log << amount
    end

    def last
      @log.last
    end
  end
end