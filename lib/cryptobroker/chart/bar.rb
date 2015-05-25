class Cryptobroker::Chart
  class Bar
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

    def append(price, amount)
      first(price) if empty?
      @weighted += price * amount
      @volume += amount
      @median[price] = @median.fetch(price, 0) + amount
      @close = price
      @low = price if price < @low
      @high = price if price > @high
    end

    def finish
      return freeze if empty?

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

      freeze
    end

    private

    def first(price)
      @open = price
      @high = price
      @low = price
      @weighted = 0
      @volume = 0
      @median = {}
    end
  end
end