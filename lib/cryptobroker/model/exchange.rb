module Cryptobroker::Model
  class Exchange < ActiveRecord::Base
    has_many :markets, inverse_of: :exchange, dependent: :destroy

    validates :name, :api_class, presence: true
    validates :name, uniqueness: true
    validate :validate_getter

    def get_api_class
      api_class.constantize
    end

    def load_api_class
      require api_class.underscore
    end

    private

    def validate_getter
      load_api_class
      get_api_class
    rescue LoadError, StandardError
      errors.add(:api_class, errors.generate_message(:api_class, :invalid))
    end
  end
end