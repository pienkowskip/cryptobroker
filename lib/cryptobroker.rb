require 'cryptobroker/version'
require 'cryptobroker/config'
require 'cryptobroker/database'

module Cryptobroker
  def initialize(config_file = 'config.yml')
    @config = Config.new(config_file)
    Database.init(@config.database[:development])
  end
end