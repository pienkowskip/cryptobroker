require 'openssl'
require 'uri'
require 'json'
require 'net/http/persistent'
require_relative '../logging'
require_relative 'cexio/error'
require_relative 'cexio/converter'
require_relative 'cexio/trade'
require_relative 'cexio/ticker'
require_relative 'cexio/order_book'
require_relative 'cexio/open_order'
require_relative 'cexio/archived_order'

module Cryptobroker::API
  class Cexio
    include Cryptobroker::Logging
    include Converter

    def initialize(auth)
      @username = auth[:username]
      @api_key = auth[:api_key]
      @api_secret = auth[:api_secret]
      @http_client = Net::HTTP::Persistent.new self.class.name
      @http_client.read_timeout = TIMEOUT
      @http_client.open_timeout = TIMEOUT
      @mutex = Mutex.new
    end

    def order_book(couple)
      OrderBook.new api_call('order_book', {}, false, couple)
    end

    def trades(couple, since = nil)
      param = since.nil? ? {} : {since: since.to_s}
      api_call('trade_history', param, false, couple).map(&Trade.method(:new)).reverse
    end

    def ticker(couple)
      Ticker.new api_call('ticker', {}, false, couple)
    end

    def balance
      api_call 'balance', {}, true
    end

    def place_order(couple, type, price, amount)
      OpenOrder.new api_call('place_order', {type: type, price: price.to_s, amount: amount.to_s}, true, couple), couple
    end

    def place_buy_order(couple, price, amount_in)
      price, price_str = norm_price price
      base_prec, quote_prec = couple.split('/').map(&method(:precision))
      amount_in = big_decimal(amount_in).truncate(quote_prec)
      amount_in -= (amount_in * TRANSACTION_FEE / (1.to_d + TRANSACTION_FEE)).ceil quote_prec
      amount_in /= price
      amount_in = amount_in.floor base_prec
      place_order couple, :buy, price_str, amount_in.to_s
    end

    def place_sell_order(couple, price, amount_in)
      _, price_str = norm_price price
      base_prec = precision(couple.split('/')[0])
      place_order couple, :sell, price_str, big_decimal(amount_in).truncate(base_prec).to_s
    end

    def cancel_order(id)
      boolean_parser = ->(answer) do
        return true if answer == 'true'
        return false if answer == 'false'
        parse_json_answer answer
      end
      api_call 'cancel_order', {id: id.to_s}, true, '', boolean_parser
    rescue LogicError => err
      return false if err.message == 'Error: Order not found'
      raise
    end

    def open_orders(couple)
      api_call('open_orders', {}, true, couple).map { |ord| OpenOrder.new ord, couple }
    end

    def archived_orders(couple, since = nil, till = nil, limit = 100)
      params = {}
      params[:dateFrom] = since unless since.nil?
      params[:dateTo] = till unless till.nil?
      params[:limit] = limit unless limit.nil?
      api_call('archived_orders', params, true, couple).map &ArchivedOrder.method(:new)
    end

    private

    API_URL = 'https://cex.io/api'
    TIMEOUT = 5
    TRANSACTION_FEE = '0.002'.to_d
    PRICE_DIGITS = 9

    def api_call(method, param = {}, priv = false, action = '', parser = nil)
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
      parser.nil? ? parse_json_answer(answer) : parser.call(answer)
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
      begin
        res = @http_client.request url, post
        res.value
      rescue Net::HTTPExceptions => err
        err = err.response
        raise err.is_a?(Net::HTTPServerError) ? ServerError : RequestError, "HTTP error: #{err.code} #{err.message}"
      rescue
        raise ConnectivityError, 'unable to connect API'
      end
      res.body
    end

    def parse_json_answer(answer)
      begin
        answer = JSON.parse(answer)
      rescue
        raise ResponseError, 'parsing response JSON failure'
      end
      raise LogicError, answer['error'] if answer.include? 'error'
      answer
    end

    def norm_price(price)
      price = big_decimal price
      exp = price.exponent
      exp = 1 if exp <= 0
      price = price.round(exp >= PRICE_DIGITS ? 0 : PRICE_DIGITS - exp)
      return price, price.frac == 0 ? price.to_i.to_s : price.to_s
    end
  end
end
