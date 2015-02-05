module Cryptobroker::Model
  class Investor < ActiveRecord::Base
    belongs_to :market
    has_many :balances, inverse_of: :investor, dependent: :destroy

    validates_belongs :market
    validates :name, presence: true, uniqueness: { scope: :market }
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
        JSON.parse conf
      end
    end

    private

    def validate_getters
      [:indicator_class, :indicator_conf, :broker_class, :broker_conf].each do |attr|
        begin
          send :"get_#{attr}"
        rescue
          errors.add(attr, errors.generate_message(attr, :invalid))
        end
      end
    end
  end
end