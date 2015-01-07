require 'indicator'

module Cryptobroker::Indicator
  class Base
    include ::Indicator
    include ::Indicator::AutoGen

    def initialize(brokers, price = :median)
      @brokers = brokers
      @price = price
    end

    protected

    def shift_nils(array)
      ri = array.rindex { |i| !i.nil? }
      return array if ri.nil?
      array.rotate! ri + 1
    end

    def signal(type, timestamp, idx)
      @brokers.each { |broker| broker.send type, timestamp, {idx: idx} }
    end
  end
end