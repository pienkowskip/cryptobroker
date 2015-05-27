module Cryptobroker::API
  class Error < StandardError
    attr_reader :cause

    def initialize(msg, cause = $!)
      super(msg)
      @cause = cause
    end
  end

  class RequestError < Error
  end

  class ResponseError < Error
  end

  class RecoverableError < Error
  end

  class ConnectivityError < RecoverableError
  end

  class ServerError < RecoverableError
  end

  class LogicError < ServerError
  end

  class InsufficientFundsError < LogicError
  end

  class InvalidAmountError < LogicError
  end
end