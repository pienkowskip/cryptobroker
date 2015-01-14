module Cryptobroker::CyclesDetector
  class Vertex
    attr_reader :id, :code, :adjacent, :path

    def initialize(id, code)
      @id = id
      @code = code
      @visited = false
      @adjacent = []
    end

    def visited?
      !!@visited
    end

    def add_edge(vertex)
      @adjacent.push(vertex)
      vertex.adjacent.push(self)
    end

    def visit(path)
      @visited = true
      @path = Array.new(path)
    end

    def reset
      @visited = false
      @path = nil
    end
  end
end