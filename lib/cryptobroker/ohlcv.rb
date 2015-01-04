class Cryptobroker::OHLCV
  def self.create(trades, period, begins = nil, ends = nil, sort = true)
    trades = trades.sort { |a,b| a.timestamp <=> b.timestamp } if sort
    begins = trades.first.timestamp if begins.nil?
    ends = trades.last.timestamp + 1 if ends.nil?

    result = []
    last = self.new begins, period
    trades
        .reject { |t| t.timestamp < begins || t.timestamp >= ends }
        .each do |trade|
      while trade.timestamp >= last.end
        unless last.empty?
          last.send :finish
          result.push last
        end
        last = self.new last.end, period
      end
      last.send :append, trade.price, trade.amount
    end
    result
  end

  attr_reader :start, :duration, :open, :high, :low, :close, :volume, :weighted, :median

  def initialize(start, duration)
    @start = start
    @duration = duration
  end

  def empty?
    @open.nil?
  end

  def end
    @start + @duration
  end

  private

  def first(price, amount)
    @open = price
    @high = price
    @low = price
    @weighted = 0
    @volume = 0
    @median = {}
  end

  def append(price, amount)
    first price, amount if empty?
    @weighted += price * amount
    @volume += amount
    @median[price] = @median.fetch(price, 0) + amount
    @close = price
    @low = price if price < @low
    @high = price if price > @high
  end

  def finish
    return if empty?

    @weighted /= @volume

    sum = 0
    median = []
    @median.keys.sort.each do |price|
      sum += @median[price]
      if sum > @volume / 2
        median.push price
        break
      elsif sum == @volume / 2
        median.push price
      end
    end
    @median = median.reduce(:+) / median.size
  end
end