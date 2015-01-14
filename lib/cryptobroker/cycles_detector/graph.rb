require_relative './vertex'

module Cryptobroker::CyclesDetector
  class Graph
    def initialize
      @graph = {}
    end

    def add_vertex(currency)
      @graph[currency.id] = Vertex.new currency.id, currency.code
    end

    def add_edge(market)
      @graph[market.base_id].add_edge @graph[market.quote_id]
    end

    def detect_cycles
      @graph.delete_if { |_,curr| curr.adjacent.empty? }
      cycles_set=Set.new
      dfs(@graph.values.first, [], cycles_set)
      @graph.values.each { |curr| curr.reset }
      cycles_set.select { |p| p.size > 2 }
    end

    private

    def dfs(vertex, path, set)
      path.push(vertex)
      vertex.visit(path)
      vertex.adjacent.each do |v|
        if v.visited?
          short, long = [path, v.path].sort_by { |i| i.size }
          set.add(long.last(long.size + 1 - short.size))
        else
          dfs(v, path, set)
        end
      end
      path.pop
    end
  end
end