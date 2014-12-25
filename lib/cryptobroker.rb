require 'cryptobroker/version'
require 'cryptobroker/config'

module Cryptobroker
  def self.hi
    config = Cryptobroker::Config.new('../config.yml')
  end
end
