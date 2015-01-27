require_relative 'basic'

module Cryptobroker::Broker
  class TransactionFee < Basic
    def initialize(type = :base, pr = :median, fee = 0.002)
      super type, pr
      @fee_factor = (1 - fee).to_d
    end

    protected

    def buy_all(price)
      @balance.base += (@balance.quote / price) * @fee_factor
      @balance.empty_quote
    end

    def sell_all(price)
      @balance.quote += (@balance.base * price) * @fee_factor
      @balance.empty_base
    end
  end
end