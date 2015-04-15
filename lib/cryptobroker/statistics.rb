require 'bigdecimal'
require 'bigdecimal/util'

module Cryptobroker::Statistics
  def middle(ar)
    ar.size % 2 == 1 ? ar[ar.size/2] : (ar[ar.size/2 - 1] + ar[ar.size/2]) / 2.0
  end

  def median(ar)
    ar.sort!
    middle(ar)
  end

  def mean(ar)
    ar.reduce(:+) / ar.size.to_d
  end

  def standard_deviation(item, ar)
    Math.sqrt(ar.reduce(0) { |accu,i| accu + (i-item)**2 } / ar.size.to_f)
  end

  def weighted_middle(ar)
    sum = 0
    median = []
    weight = ar.map { |i| i[1] }.reduce(:+)
    ar.each do |val,w|
      sum += w
      if sum > weight / 2.0
        median.push val
        break
      elsif sum == weight / 2.0
        median.push val
      end
    end
    mean(median)
  end

  def weighted_median(ar)
    ar.sort_by! { |i| i[0] }
    weighted_middle(ar)
  end

  def weighted_mean(ar)
    sum = 0
    weight = 0
    ar.each do |val,w|
      sum += val * w
      weight += w
    end
    sum / weight.to_d
  end

  def weighted_standard_deviation(item, ar)
    sum = 0
    weight = 0
    ar.each do |val,w|
      sum += ((val-item)**2) * w
      weight += w
    end
    Math.sqrt sum / weight.to_f
  end
end