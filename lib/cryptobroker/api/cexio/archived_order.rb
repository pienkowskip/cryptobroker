require_relative 'entity'

class Cryptobroker::API::Cexio::ArchivedOrder < Cryptobroker::API::Cexio::Entity
  attr_reader :id, :type, :timestamp, :price, :base_amount, :base_remained, :quote_amount, :quote_fee, :status

  def initialize(raw_order)
    set_attrs raw_order, id: 'orderId', type: 'type', timestamp: 'time',
              price: 'price', base_amount: 'amount', base_remained: 'remains', status: 'status'
    qc = raw_order.fetch('symbol2')
    @quote_amount = raw_order.fetch "ta:#{qc}", 0
    @quote_fee = raw_order.fetch "fa:#{qc}", 0
    md = /\A([0-9]+)\.([0-9]+)\z/.match base_amount
    raise ArgumentError, 'invalid amount' unless md
    @base_remained = @base_remained.to_s.rjust(md[1].length + md[2].length, '0').insert(md[1].length, '.')
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
  end

  def base_change
    ch = base_amount - base_remained
    type == :sell ? -ch : ch
  end

  def quote_change
    (type == :buy ? -quote_amount : quote_amount) - quote_fee
  end
end