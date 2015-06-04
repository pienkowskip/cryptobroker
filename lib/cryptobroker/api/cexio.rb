require 'openssl'
require 'uri'
require 'oj'
require 'net/http/persistent'
require_relative '../utility/logging'
require_relative 'errors'
require_relative 'cexio/converter'
require_relative 'cexio/trade'
require_relative 'cexio/ticker'
require_relative 'cexio/order_book'
require_relative 'cexio/open_order'
require_relative 'cexio/archived_order'

module Cryptobroker::API
  class Cexio
    include Cryptobroker::Utility::Logging
    include Converter

    API_URL = 'https://cex.io/api'.freeze
    TIMEOUT = 5
    TRANSACTION_FEE = '0.002'.to_d
    PRICE_DIGITS = 9
    AMOUNT_DECREMENTS = 2

    def initialize(auth)
      @username = auth.fetch :username
      @api_key = auth.fetch :api_key
      @api_secret = auth.fetch :api_secret
      @http_client = Net::HTTP::Persistent.new self.class.name
      @http_client.read_timeout = TIMEOUT
      @http_client.open_timeout = TIMEOUT
      @mutex = Mutex.new
    end

    def order_book(couple)
      OrderBook.new api_call('order_book', {}, false, couple)
    end

    def trades(couple, since = nil)
      param = since.nil? ? {} : {since: Integer(since).to_s}
      api_call('trade_history', param, false, couple).map(&Trade.method(:new)).reverse
    end

    def ticker(couple)
      Ticker.new api_call('ticker', {}, false, couple)
    end

    def balance
      api_call 'balance', {}, true
    end

    def place_buy_order(couple, price, amount_in)
      price, price_str = norm_price price
      base_prec, quote_prec = split_couple(couple).map(&method(:precision))
      place_order_amount_decrementer big_decimal(amount_in).truncate(quote_prec), quote_prec do |amount|
        amount -= (amount * TRANSACTION_FEE / (1.to_d + TRANSACTION_FEE)).ceil quote_prec
        amount /= price
        amount = amount.floor base_prec
        place_order couple, :buy, price_str, amount
      end
    end

    def place_sell_order(couple, price, amount_in)
      _, price_str = norm_price price
      base_prec = precision(split_couple(couple)[0])
      place_order_amount_decrementer big_decimal(amount_in).truncate(base_prec), base_prec do |amount|
        place_order couple, :sell, price_str, amount
      end
    end

    def cancel_order(id)
      boolean_parser = ->(answer) do
        return true if answer == 'true'
        return false if answer == 'false'
        parse_json_answer answer
      end
      api_call 'cancel_order', {id: id.to_s}, true, '', boolean_parser
    rescue Cryptobroker::API::LogicError => err
      return false if err.message == 'Error: Order not found'
      raise
    end

    def open_orders(couple)
      api_call('open_orders', {}, true, couple).map { |ord| OpenOrder.new ord, couple }
    end

    def archived_orders(couple, since = nil, till = nil, limit = 100)
      params = {}
      params[:dateFrom] = Time.at(since).to_f.to_s unless since.nil?
      params[:dateTo] = Time.at(till).to_f.to_s unless till.nil?
      params[:limit] = Integer(limit).to_s unless limit.nil?
      api_call('archived_orders', params, true, couple).map &ArchivedOrder.method(:new)
    end

    private

    def place_order_amount_decrementer(amount, precision)
      decrements = AMOUNT_DECREMENTS
      begin
        yield amount
      rescue Cryptobroker::API::InsufficientFundsError => err
        raise err if decrements <= 0
        decrements -= 1
        amount -= Rational(1, 10 ** precision).to_d(1)
        retry
      end
    end

    def place_order(couple, type, price, amount)
      OpenOrder.new api_call('place_order', {type: type.to_s, price: price.to_s, amount: amount.to_s}, true, couple), couple
    rescue Cryptobroker::API::LogicError => err
      raise Cryptobroker::API::InsufficientFundsError, err.message if err.message == 'Error: Place order error: Insufficient funds.'
      raise Cryptobroker::API::InvalidAmountError, err.message if err.message == 'Invalid amount'
      raise
    end

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
        raise err.is_a?(Net::HTTPServerError) ? Cryptobroker::API::ServerError : Cryptobroker::API::RequestError,
              "HTTP error: #{err.code} #{err.message}"
      rescue
        raise Cryptobroker::API::ConnectivityError, 'unable to connect API'
      end
      res.body
    end

    def parse_json_answer(answer)
      begin
        answer = Oj.load(answer, bigdecimal_load: :bigdecimal)
      rescue
        raise Cryptobroker::API::ResponseError, 'parsing response JSON failure'
      end
      raise Cryptobroker::API::LogicError, answer['error'] if answer.include? 'error'
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
