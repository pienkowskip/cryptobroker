require_relative 'entity'

class Cryptobroker::API::Cexio::OrderBook < Cryptobroker::API::Cexio::Entity
  attr_reader :timestamp, :asks, :bids

  def initialize(raw_order_book)
    set_attrs raw_order_book, timestamp: 'timestamp', asks: 'asks', bids: 'bids'
    map = ->(ar) { ar.map { |price, amount| [big_decimal(price), big_decimal(amount)] }.sort_by { |i| i[0] } }
    convert_attrs timestamp: :time, asks: map, bids: ->(ar) { map[ar].reverse }
  rescue
    raise create_response_error
  end
end