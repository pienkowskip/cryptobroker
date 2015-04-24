require 'yaml'
require_relative 'logging'

class Cryptobroker::Config
  attr_reader :application, :auth, :database

  def initialize(fname = 'config.yml')
    config = deep_symbolize_keys(YAML.load_file(fname))
    [:database, :auth, :application].each do |key|
      raise 'configuration file not sufficient' unless config.include? key
      instance_variable_set :"@#{key}", config[key]
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
    Cryptobroker::Logging.setup file, level
    true
  rescue
    raise 'application.logger configuration entry invalid'
  end

  def deep_symbolize_keys(hash)
    return hash unless hash.is_a?(Hash)
    hash.keys.each do |key|
      hash[(key.to_sym rescue key)] = deep_symbolize_keys(hash.delete(key))
    end
    hash
  end
end