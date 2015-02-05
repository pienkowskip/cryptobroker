module Cryptobroker::Model
  class Balance < ActiveRecord::Base
    belongs_to :investor
    has_one :trade, foreign_key: 'balance_id', class_name: 'Transaction', inverse_of: :balance, dependent: :destroy

    default_scope -> { order :timestamp, :id }

    validates_belongs :investor
    validates :base, :quote, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates_before_type_case :timestamp, presence: true
    validates_class :timestamp, class: [Time, DateTime]
  end
end