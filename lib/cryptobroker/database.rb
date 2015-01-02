class Cryptobroker::Database
  def self.init(config)
    require 'active_record'
    Dir.glob(File.dirname(__FILE__) + '/models/*.rb').each { |model| require model }
    ActiveRecord::Base.establish_connection(config)
  end
end