require_relative 'entity'

class Cryptobroker::API::Cexio::OrderBook < Cryptobroker::API::Cexio::Entity
  attr_reader :timestamp, :asks, :bids

  def initialize(json)
    set_attrs json, timestamp: 'timestamp', asks: 'asks', bids: 'bids'
    map = ->(ar) { ar.map { |price, amount| [big_decimal(price), big_decimal(amount)] }.sort_by { |i| i[0] } }
    convert_attrs timestamp: :time, asks: map, bids: ->(ar) { map[ar].reverse }
  rescue
    raise Cryptobroker::API::Cexio::ResponseError
  end
end