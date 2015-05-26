require 'yaml'
require 'active_support/core_ext/string/inflections'
require 'bigdecimal'
require 'bigdecimal/util'
require_relative '../exceptions'

module Cryptobroker::Evaluator
  class Config
    ENTRIES = [:indicators, :timeframes, :prices, :transaction_fee, :min_sample_size].freeze

    attr_reader *ENTRIES

    def initialize(filename)
      begin
        config = YAML.load_file(filename)
      rescue SyntaxError
        raise Cryptobroker::ConfigError, 'configuration file invalid syntax'
      end
      ENTRIES.each do |key|
        key = key.to_s
        raise Cryptobroker::ConfigError, "configuration file not sufficient: missing '#{key}' entry" unless config.include? key
        value = begin
          send(:"parse_#{key}", config[key])
        rescue => err
          raise Cryptobroker::ConfigEntryError.new(key, err)
        end
        instance_variable_set(:"@#{key}", value)
      end
    end

    private

    def parse_indicators(indicators)
      raise ArgumentError, 'invalid structure' unless indicators.is_a?(Hash)
      indicator_setups(indicators)
    end

    def indicator_setups(configs, indicator_name = '')
      if configs.is_a?(Hash)
        indicators = []
        indicator_name << '::' unless indicator_name.empty?
        configs.each { |name, subtree| indicators.concat(indicator_setups(subtree, indicator_name + name.to_s)) }
        indicators
      elsif configs.is_a?(Array)
        require indicator_name.underscore
        indicator = indicator_name.constantize
        keys = configs.first
        configs[1..-1].map! { |values| [indicator, Hash[keys.zip(values)]] }
      elsif configs.nil?
        []
      else
        raise ArgumentError, 'invalid structure'
      end
    end

    def parse_timeframes(timeframes)
      raise ArgumentError, 'invalid format' unless timeframes.is_a?(Array)
      timeframes.map! { |tf| tf * 60 }
    end

    def parse_prices(prices)
      raise ArgumentError, 'invalid structure' unless prices.is_a?(Array)
      prices.map! { |price| price.to_sym }
    end

    def parse_transaction_fee(tf)
      Float tf
      tf.to_d
    end

    def parse_min_sample_size(mss)
      Integer mss
    end
  end
end