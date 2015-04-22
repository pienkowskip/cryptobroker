require_relative 'entity'

class Cryptobroker::API::Cexio::OpenOrder < Cryptobroker::API::Cexio::Entity
  attr_reader :id, :type, :timestamp, :price, :base_amount, :base_pending

  def initialize(raw_order, couple)
    set_attrs raw_order, timestamp: 'time', id: 'id', type: 'type', price: 'price', base_amount: 'amount', base_pending: 'pending'
    convert_attrs timestamp: ->(ts) { Time.at(Float(ts) / 1000.0) }, id: :Integer, type: :order_type,
                  price: :big_decimal, base_amount: :big_decimal, base_pending: :big_decimal
    @quote_prec = precision split_couple(couple)[1]
  rescue
    raise Cryptobroker::API::Cexio::ResponseError
  end

  def base_completed
    base_amount - base_pending
  end

  [:amount, :completed].each do |sym|
    define_method(:"quote_#{sym}") { base_to_quote send(:"base_#{sym}") }
  end

  def completed?
    base_pending <= 0
  end

  private

  def base_to_quote(amount)
    quote = amount * price
    if type == :buy
      quote.ceil(@quote_prec) + (quote * Cryptobroker::API::Cexio::TRANSACTION_FEE).ceil(@quote_prec)
    else
      quote.floor(@quote_prec) - (quote * Cryptobroker::API::Cexio::TRANSACTION_FEE).ceil(@quote_prec)
    end
  end
end