class Exchange < ActiveRecord::Base
  has_many :markets, inverse_of: :exchange, dependent: :destroy

  validates :name, :api, presence: true
  validates :name, uniqueness: true
end