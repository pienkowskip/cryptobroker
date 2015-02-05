module Cryptobroker::Model
  class Transaction < ActiveRecord::Base
    TYPES = ['buy', 'sell']
    self.inheritance_column = nil

    belongs_to :balance

    validates_belongs :balance
    validates :type, presence: true, inclusion: TYPES
    validates :amount, :price, presence: true, numericality: { greater_than: 0 }
  end
end