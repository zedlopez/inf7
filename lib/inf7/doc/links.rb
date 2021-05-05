require 'yaml'
module Inf7


class Doc::Links
    @links = {}
    class << self
      def []=(x,y)
        @links[File.basename(x)] = y
      end
      def [](x)
        @links[File.basename(x)]
      end
      def dump
        YAML.dump(@links)
      end
      def load(hash)
        @links = hash
      end
    end
  end
  
end
