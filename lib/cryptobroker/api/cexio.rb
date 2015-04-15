require 'openssl'
require 'uri'
require 'json'
require 'net/http/persistent'
require 'bigdecimal'
require 'bigdecimal/util'
require_relative '../logging'

class BigDecimal
  DEFAULT_STR_FORMAT = 'F'

  def to_fmt_s(fmt = DEFAULT_STR_FORMAT, *args)
    _org_to_s fmt, *args
  end

  alias_method :_org_to_s, :to_s
  alias_method :to_s, :to_fmt_s
end


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
      orders = api_call 'order_book', {}, false, couple
      orders = map_hash orders, timestamp: 'timestamp', asks: 'asks', bids: 'bids'
      map = ->(ar) { ar.map { |price,amount| [big_decimal(price), big_decimal(amount)] }.sort_by { |i| i[0] } }
      convert_hash orders,
                   timestamp: method(:timestamp),
                   asks: map,
                   bids: ->(ar) { map[ar].reverse }
    end

    def trades(couple, since = nil)
      param = since.nil? ? {} : {since: since.to_s}
      trades = api_call 'trade_history', param, false, couple
      trades.map! do |t|
        t = map_hash t, amount: 'amount', price: 'price', tid: 'tid', timestamp: 'date'
        convert_hash t,
                     timestamp: method(:timestamp),
                     tid: method(:Integer),
                     amount: method(:big_decimal), price: method(:big_decimal)
      end
      trades.reverse
    end

    def ticker(couple)
      ticker = api_call 'ticker', {}, false, couple
      ticker = map_hash ticker, timestamp: 'timestamp', bid: 'bid', ask: 'ask', last: 'last'
      convert_hash ticker,
                   timestamp: method(:timestamp),
                   bid: method(:big_decimal), ask: method(:big_decimal), last: method(:big_decimal)
    end

    def balance
      api_call 'balance', {}, true
    end

    def place_order(couple, type, price, amount)
      order api_call('place_order', {type: type, price: price.to_s, amount: amount.to_s}, true, couple)
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
    rescue Error => e
      return false if e.message == 'Error: Order not found'
      raise e
    end

    def open_orders(couple)
      api_call('open_orders', {}, true, couple).map &method(:order)
    end

    def archived_orders(couple, since = nil, till = nil, limit = 100)
      params = {}
      params[:dateFrom] = since unless since.nil?
      params[:dateTo] = till unless till.nil?
      params[:limit] = limit unless limit.nil?
      api_call 'archived_orders', params, true, couple
    end

    private

    API_URL = 'https://cex.io/api'
    TIMEOUT = 5
    TRANSACTION_FEE = '0.002'.to_d
    PRICE_DIGITS = 9
    DEFAULT_CURRENCY_PREC = 8
    CURRENCY_PRECS = {
        USD: 2, EUR: 2, DOGE: 2, FTC: 2, AUR: 2, DVC: 2, POT: 2, ANC: 2, MEC: 2, WDC: 2, DGB: 2, USDE: 2, MYR: 2,
        GHS: 8, BTC: 8, NMC: 8, LTC: 8, IXC: 8, DRK: 8
    }

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
      res = @http_client.request url, post
      res.value
      res.body
    end

    def map_hash(hash, mapper)
      new_hash = {}
      mapper.each do |to,from|
        raise Error, 'invalid data received from request' unless hash.include? from
        new_hash[to] = hash[from]
      end
      new_hash
    end

    def convert_hash(hash, converters)
      converters.each { |key,converter| hash[key] = converter.call hash[key] }
      hash
    end

    def big_decimal(str)
      Float str
      str.to_d
    end

    def timestamp(ts)
      Time.at Float(ts)
    end

    def order(order)
      order = map_hash order, timestamp: 'time', id: 'id', type: 'type', price: 'price', base_amount: 'amount', base_pending: 'pending'
      convert_hash order,
                   timestamp: ->(ts) { Time.at(Float(ts) / 1000.0) },
                   id: method(:Integer),
                   price: method(:big_decimal), base_amount: method(:big_decimal), base_pending: method(:big_decimal)
    end

    def parse_json_answer(answer)
      answer = JSON.parse(answer)
      raise Error, answer['error'] if answer.include? 'error'
      answer
    end

    def norm_price(price)
      price = big_decimal price
      exp = price.exponent
      exp = 1 if exp <= 0
      price = price.round(exp >= PRICE_DIGITS ? 0 : PRICE_DIGITS - exp)
      return price, price.frac == 0 ? price.to_i.to_s : price.to_s
    end

    def precision(currency)
      currency = currency.to_sym rescue currency
      CURRENCY_PRECS.fetch currency, DEFAULT_CURRENCY_PREC
    end
  end
end
