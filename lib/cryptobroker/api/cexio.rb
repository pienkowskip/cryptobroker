# -*- encoding : utf-8 -*-
require 'openssl'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'addressable/uri'

module Cryptobroker::API
  class Cexio
    def initialize(auth)
      @username = auth[:username]
      @api_key = auth[:api_key]
      @api_secret = auth[:api_secret]
      @logger = Logger.new(STDOUT)
      @api_uri = URI.parse(API_URL)
      @http_client = Net::HTTP.new(@api_uri.host, @api_uri.port)
      @http_client.use_ssl = true
      @http_client.read_timeout = TIMEOUT
      @http_client.open_timeout = TIMEOUT
      @http_client.continue_timeout = TIMEOUT
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

    private

    API_URL = 'https://cex.io/api'
    TIMEOUT = 5

    def api_call(method, param = {}, priv = false, action = '', is_json = true)
      url = "#{@api_uri.path}/#{method}/#{action}"
      if priv
        nonce
        param.merge!(key: @api_key, signature: signature.to_s, nonce: @nonce)
      end
      answer = post(url, param)

      # unfortunately, the API does not always respond with JSON, so we must only
      # parse as JSON if is_json is true.
      if is_json
        JSON.parse(answer)
      else
        answer
      end
    end

    def nonce
      @nonce = (Time.now.to_f * 1000000).to_i.to_s
    end

    def signature
      str = @nonce + @username + @api_key
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha256'), @api_secret, str)
    end

    def post(path, param)
      @logger.debug(self.class.to_s) { "Posting to URI '#{path}' params: #{param}." }
      params = Addressable::URI.new
      params.query_values = param
      @http_client.post(path, params.query).body
    end
  end
end
