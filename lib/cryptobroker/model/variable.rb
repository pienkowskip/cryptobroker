module Cryptobroker::Model
  class Variable < ActiveRecord::Base
    belongs_to :investor

    validates_belongs :investor
    validates :name, presence: true, format: {with: /\A[a-zA-Z0-9_]+\z/}, uniqueness: { scope: :investor }
    validate :validate_getter

    def get_value
      return nil if value.nil?
      Marshal.load value
    end

    def set_value(value)
      self.value = value.nil? ? nil : Marshal.dump(value)
    end

    def set_value!(value)
      set_value(value)
      save!
    end

    private

    def validate_getter
      get_value
    rescue
      errors.add(:value, errors.generate_message(:value, :invalid))
    end
  end
end