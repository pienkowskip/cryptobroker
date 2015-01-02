class Currency < ActiveRecord::Base
  validates :code, :name, presence: true
  validates :code, length: { is: 3 }
  validates :code, uniqueness: true
  validates :crypto, inclusion: [true, false]
end