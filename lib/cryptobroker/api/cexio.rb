require 'openssl'
require 'uri'
require 'json'
require 'net/http/persistent'
require_relative '../logging'

module Cryptobroker::API
  class Cexio
    class Error < Exception; end
    include Cryptobroker::Logging

    def initialize(auth)
      @username = auth[:username]
      @api_key = auth[:api_key]
      @api_secret = auth[:api_secret]
      @http_client = Net::HTTP::Persistent.new self.class.name
      @http_client.read_timeout = TIMEOUT
      @http_client.open_timeout = TIMEOUT
      @mutex = Mutex.new
    end

    def orders(couple)
      orders = api_call('order_book', {}, false, couple)
      orders[:timestamp] = Time.at(Integer(orders.delete('timestamp')))
      map = ->(ar) { ar.map { |price,amount| [price.to_d, amount.to_d] }.sort_by { |i| i[0] } }
      orders[:asks] = map[orders.delete('asks')]
      orders[:bids] = map[orders.delete('bids')].reverse
      orders
    end

    def trades(since, couple)
      param = since.nil? ? {} : {since: since.to_s}
      api_call('trade_history', param, false, couple)
          .map { |t| t['timestamp'] = Time.at(Integer(t.delete('date'))) ; t }
          .reverse
    end

    def balance
      api_call 'balance', {}, true
    end

    private

    API_URL = 'https://cex.io/api'
    TIMEOUT = 5

    def api_call(method, param = {}, priv = false, action = '', is_json = true)
      url = "#{API_URL}/#{method}/#{action}"
      begin
        if priv
          @mutex.lock
          nonce
          param.merge!(key: @api_key, signature: signature.to_s, nonce: @nonce)
        end
        answer = post(url, param)
      ensure
        @mutex.unlock if priv
      end
      if is_json
        answer = JSON.parse(answer)
        raise Error, answer['error'] if answer.include? 'error'
      end
      answer
    end

    def nonce
      @nonce = (Time.now.to_f * 1000000).to_i.to_s
    end

    def signature
      str = @nonce + @username + @api_key
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha256'), @api_secret, str)
    end

    def post(url, param)
      logger.debug { "Posting to URL [#{url}] params: #{param}." }
      url = URI url
      post = Net::HTTP::Post.new url.path
      post.set_form_data param
      res = @http_client.request url, post
      res.value
      res.body
    end
  end
end
