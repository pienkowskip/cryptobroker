class Trade < ActiveRecord::Base
  belongs_to :market

  validates_belongs :market
  validates :amount, :price, presence: true, numericality: { greater_than: 0 }
  validates_before_type_case :timestamp, presence: true
  validates_class :timestamp, class: [Time, DateTime]
  validates :tid, numericality: { only_integer: true }, allow_nil: true
end