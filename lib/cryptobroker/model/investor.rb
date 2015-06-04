require 'oj'

module Cryptobroker::Model
  class Investor < ActiveRecord::Base
    belongs_to :market
    has_many :balances, inverse_of: :investor, dependent: :destroy
    has_many :variables, inverse_of: :investor, dependent: :destroy

    scope :enabled, -> { where(enabled: true) }

    validates_belongs :market
    validates :name, presence: true, uniqueness: { scope: :market }
    validates :enabled, inclusion: [true, false]
    validates :indicator_class, :broker_class, presence: true
    validate :validate_getters
    validates :timeframe, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates_before_type_case :beginning, presence: true
    validates_class :beginning, class: [Time, DateTime]

    [:indicator, :broker].each do |attr|
      define_method :"get_#{attr}_class" do
        send(:"#{attr}_class").constantize
      end

      define_method :"get_#{attr}_conf" do
        conf = send(:"#{attr}_conf")
        return nil if conf.nil?
        Oj.load(conf, bigdecimal_load: :bigdecimal).deep_symbolize_keys
      end
    end

    def load_classes
      [:indicator, :broker].each { |attr| require send(:"#{attr}_class").underscore }
    end

    private

    def validate_getters
      [:indicator_class, :broker_class].each { |attr| validate_class attr }
      [:indicator_conf, :broker_conf].each { |attr| validate_conf attr }
    end

    def validate_class(attr)
      require send(:"#{attr}").underscore
      send :"get_#{attr}"
    rescue LoadError, StandardError
      errors.add(attr, errors.generate_message(attr, :invalid))
    end

    def validate_conf(attr)
      send :"get_#{attr}"
    rescue
      errors.add(attr, errors.generate_message(attr, :invalid))
    end
  end
end