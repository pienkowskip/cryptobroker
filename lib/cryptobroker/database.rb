class Cryptobroker::Database
  def self.init(config)
    require 'active_record'

    ActiveRecord::Base.class_eval do
      def self.validates_belongs(*attr_names)
        validates *(attr_names.map { |attr| :"#{attr}_id" }), presence: true
        validates_each *attr_names do |record, attr, value|
                         record.errors.add(:"#{attr}_id", record.errors.generate_message(:"#{attr}_id", :invalid)) if value == nil
                       end
      end

      def self.validates_class(*attr_names)
        options = attr_names.extract_options!
        cls = options.delete(:class)
        unless cls.is_a?(Array)
          cls = [cls]
        end
        cls.select! { |i| i.is_a?(Class) }
        return unless cls.length > 0
        validates_each *attr_names, options do |record, attr, value|
          record.errors.add(:"#{attr}", record.errors.generate_message(:"#{attr}", :invalid)) unless self.class_inclusion cls, value
        end
      end

      def self.validates_before_type_case(*attr_names)
        options = attr_names.extract_options!
        btcs = attr_names.map { |attr| :"#{attr}_before_type_cast" }
        validates *btcs, options
        validates_each *attr_names do |record, attr, value|
                         attr_btc = :"#{attr}_before_type_cast"
                         next unless record.errors.include?(attr_btc)
                         msgs = record.errors.delete(attr_btc)
                         msgs.each { |msg| record.errors.add(attr, msg) }
                       end
      end

      private
      def self.class_inclusion(classes, value)
        for cls in classes do
          return true if value.is_a?(cls)
        end
        return false
      end
    end

    Dir.glob(File.dirname(__FILE__) + '/models/*.rb').each { |model| require_relative model }

    ActiveRecord::Base.establish_connection(config)
    ActiveRecord::Base.logger = Logger.new(STDOUT)
  end
end