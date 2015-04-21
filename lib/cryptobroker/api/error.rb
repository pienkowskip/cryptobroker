module Cryptobroker::API
  class Error < StandardError
    attr_reader :cause

    def initialize(msg, cause = $!)
      super(msg)
      @cause = cause
    end
  end

  module RecoverableError
  end
end