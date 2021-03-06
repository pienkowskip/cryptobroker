class Cryptobroker
  class ConfigError < RuntimeError
  end

  class ConfigEntryError < ConfigError
    def initialize(entry_name, cause)
      msg = "#{entry_name} configuration entry invalid"
      msg << ' - ' << cause.to_s unless cause.to_s.empty?
      super(msg)
    end
  end
end