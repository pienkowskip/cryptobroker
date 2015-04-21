require_relative '../error'

module Cryptobroker::API
  class Cexio
    class Error < Cryptobroker::API::Error
    end

    class RequestError < Error
    end

    class ResponseError < Error
      def initialize(msg = 'invalid response data', cause = $!)
        super
      end
    end

    class ConnectivityError < Error
      include Cryptobroker::API::RecoverableError
    end

    class ServerError < Error
      include Cryptobroker::API::RecoverableError
    end

    class LogicError < ServerError
    end
  end
end