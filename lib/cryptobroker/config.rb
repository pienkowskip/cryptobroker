require 'yaml'
require_relative 'utility/logging'
require_relative 'exceptions'

class Cryptobroker::Config
  attr_reader :application, :auth, :database

  def initialize(fname = 'config.yml')
    begin
      config = deep_symbolize_keys(YAML.load_file(fname))
    rescue SyntaxError
      raise Cryptobroker::ConfigError, 'configuration file invalid syntax'
    end
    [:database, :auth, :application].each do |key|
      raise Cryptobroker::ConfigError, "configuration file not sufficient: missing '#{key}' entry" unless config.include? key
      instance_variable_set :"@#{key}", config[key].freeze
    end
    setup_logger
  end

  private

  def setup_logger
    return false unless application.include? :logger
    logger = application[:logger]
    logdev_map = {
        '<stdout>' => STDOUT,
        '<stderr>' => STDERR
    }
    file = logger.fetch :file
    file = logdev_map[file.downcase] if logdev_map.include? file.downcase
    level = Logger::Severity.const_get(logger.fetch(:level).upcase.to_sym, false)
    Cryptobroker::Utility::Logging.setup file, level
    true
  rescue => err
    raise Cryptobroker::ConfigEntryError.new('application.logger', err)
  end

  def deep_symbolize_keys(hash)
    return hash unless hash.is_a?(Hash)
    hash.keys.each do |key|
      hash[(key.to_sym rescue key)] = deep_symbolize_keys(hash.delete(key))
    end
    hash
  end
end