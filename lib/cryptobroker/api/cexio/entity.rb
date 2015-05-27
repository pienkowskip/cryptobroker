require_relative 'converter'
require_relative '../../api/errors'

module Cryptobroker::API
  class Cexio
    class Entity
      include Cryptobroker::API::Cexio::Converter

      def to_hash(disallowed = [])
        hash = {}
        methods = self.class.public_instance_methods(false)
        disallowed << :to_hash
        methods.reject! { |m| disallowed.include? m }
        methods.each { |k| hash[k] = send k }
        hash
      end

      protected

      def set_attrs(hash, mapper)
        mapper.each { |attr, from| instance_variable_set :"@#{attr}", hash.fetch(from) }
      end

      def convert_attrs(converters)
        converters.each do |attr, converter|
          attr = :"@#{attr}"
          converter = method converter if converter.is_a?(Symbol) || converter.is_a?(String)
          instance_variable_set attr, converter.call(instance_variable_get attr)
        end
      end

      def create_response_error
        Cryptobroker::API::ResponseError.new('invalid response data')
      end
    end
  end
end