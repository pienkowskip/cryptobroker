require 'thread'
require_relative '../../api/error'

module Cryptobroker::Broker
  class Smart
    class Confirmator
      RETRY_DELAY = 15
      TIME_SPAN_HALF = 1

      def initialize(trader, api, couple)
        @trader, @api, @couple = trader, api, couple
        @queue = Queue.new
        @thread = Thread.new do
          loop { perform_confirm *@queue.pop }
        end
        @thread.abort_on_exception = true
      end

      def confirm(id, timestamp)
        @queue.push [id, timestamp]
      end

      private

      def perform_confirm(id, timestamp)
        loop do
          order = begin
            api.archived_orders(@couple, timestamp - TIME_SPAN_HALF, timestamp - TIME_SPAN_HALF)
                .find { |ord| ord.id == id }
          rescue Cryptobroker::API::RecoverableError
            nil
          end
          unless order.nil?
            @trader.confirm_order(order)
            break
          end
          sleep RETRY_DELAY
        end
      end
    end
  end
end