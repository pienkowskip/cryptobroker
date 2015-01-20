module Cryptobroker::Broker
  class Relative
    def initialize(type, price, fee)
      @type = type
      @price = price
      @fee_factor = (1 - fee).to_d
    end

    def reset(market)
      @market = market
      @last_tr_type = nil
      @transactions = []
    end

    def sell(timestamp, params = {})
      add_transaction :quote, timestamp, params
    end

    def buy(timestamp, params = {})
      add_transaction :base, timestamp, params
    end

    def results
      status = @type
      results = []
      price = nil
      trs = @transactions.to_enum
      next_tr = @transactions.empty? ? nil : trs.next
      ratio = @type == :quote ? ->(pr, lpr) { pr / lpr } : ->(pr, lpr) { lpr / pr }
      @market.each_with_index do |chunk, i|
        last_price = price
        price = chunk.send @price
        if next_tr == i
          status = invert_type status
          if status == @type
            results << ratio[price, last_price] * @fee_factor - 1
          else
            results << @fee_factor - 1.to_d
          end
          begin
            next_tr = trs.next
          rescue StopIteration
            next_tr = nil
          end
          next
        end
        if status == @type
          results << 0
        else
          results << ratio[price, last_price] - 1
        end
      end
      results.push results.pop + @fee_factor - 1.to_d unless @last_tr_type.nil? || @last_tr_type == @type
      results
    end

    protected

    def invert_type(type)
      return :base if type == :quote
      return :quote if type == :base
      nil
    end

    def add_transaction(type, timestamp, params)
      return if @transactions.empty? && type == @type
      return unless @last_tr_type.nil? || @last_tr_type != type
      return unless params[:idx] + 1 < @market.size
      @last_tr_type = type
      @transactions << params[:idx] + 1
    end
  end
end