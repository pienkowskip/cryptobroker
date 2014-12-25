require 'yaml'

class Cryptobroker::Config
  attr_reader :database, :auth

  def initialize(fname = 'config.yml')
    config = deep_symbolize_keys(YAML.load_file(fname))
    raise 'configuration file not sufficient' unless config.include?(:database) && config.include?(:auth)
    @database = config[:database]
    @auth = config[:auth]
  end

  private

  def deep_symbolize_keys(hash)
    return hash unless hash.is_a?(Hash)
    hash.keys.each do |key|
      hash[(key.to_sym rescue key) || key] = deep_symbolize_keys(hash.delete(key))
    end
    hash
  end
end