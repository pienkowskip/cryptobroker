require_relative 'entity'

class Cryptobroker::API::Cexio::Trade < Cryptobroker::API::Cexio::Entity
  attr_reader :amount, :price, :tid, :timestamp

  def initialize(raw_trade)
    set_attrs raw_trade, amount: 'amount', price: 'price', tid: 'tid', timestamp: 'date'
    convert_attrs timestamp: :time, tid: :Integer, amount: :big_decimal, price: :big_decimal
  end
end