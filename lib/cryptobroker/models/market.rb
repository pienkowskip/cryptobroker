class Market < ActiveRecord::Base
  belongs_to :exchange
  belongs_to :base, class_name: 'Currency'
  belongs_to :quote, class_name: 'Currency'
  has_many :trades, inverse_of: :market, dependent: :destroy

  validates_belongs :exchange, :base, :quote
  validates :traced, inclusion: [true, false]
end