require 'bigdecimal'
require 'bigdecimal/util'

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
    module Converter

      DEFAULT_CURRENCY_PRECISION = 8
      CURRENCY_PRECISIONS = {
          USD: 2, EUR: 2, DOGE: 2, FTC: 2, AUR: 2, DVC: 2, POT: 2, ANC: 2, MEC: 2, WDC: 2, DGB: 2, USDE: 2, MYR: 2,
          GHS: 8, BTC: 8, NMC: 8, LTC: 8, IXC: 8, DRK: 8
      }

      protected

      def big_decimal(str)
        Float str
        str.to_d
      end

      def time(ts)
        Time.at Float(ts)
      end

      def order_type(type)
        type = type.to_sym
        raise ArgumentError, 'invalid order type' unless [:buy, :sell].include? type
        type
      end

      def precision(currency)
        currency = currency.to_sym rescue currency
        CURRENCY_PRECISIONS.fetch currency, DEFAULT_CURRENCY_PRECISION
      end

      def split_couple(couple)
        couple = couple.split '/'
        raise ArgumentError, 'invalid couple format ' unless couple.size == 2
        couple
      end
    end
  end
end