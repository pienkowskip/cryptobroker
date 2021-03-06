require_relative 'entity'

class Cryptobroker::API::Cexio::ArchivedOrder < Cryptobroker::API::Cexio::Entity
  attr_reader :id, :type, :timestamp, :price, :base_amount, :base_remained, :quote_amount, :quote_fee, :status

  def initialize(raw_order)
    set_attrs raw_order, id: 'orderId', type: 'type', timestamp: 'time',
              price: 'price', base_amount: 'amount', base_remained: 'remains', status: 'status'
    qc = raw_order.fetch('symbol2')
    @quote_amount = raw_order.fetch "ta:#{qc}", 0
    @quote_fee = raw_order.fetch "fa:#{qc}", 0
    convert_attrs id: :Integer, type: :order_type, timestamp: ->(ts) { Time.parse(ts) },
                  status: ->(status) do
                    if status == 'd'
                      :completed
                    elsif status == 'c'
                      :cancelled
                    else
                      raise ArgumentError, 'invalid status'
                    end
                  end,
                  price: :big_decimal, base_amount: :big_decimal, base_remained: :big_decimal,
                  quote_amount: :big_decimal, quote_fee: :big_decimal
  rescue
    raise create_response_error
  end

  def base_completed
    base_amount - base_remained
  end

  def base_change
    type == :sell ? -base_completed : base_completed
  end

  def quote_change
    (type == :buy ? -quote_amount : quote_amount) - quote_fee
  end
end