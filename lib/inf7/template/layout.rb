module Inf7
  class  Template
  class Layout < Template
    class << self
      def [](hash)
        return nil if hash.key?(:layout) and !(hash.key?(:layout))
        self.new(hash[:layout] || :default)
      end
      
      def path(template_name)
        super(File.join('layout', template_name))
      end

    end
      
    def initialize(template)
#      puts "making layout #{template}"
        super(File.join('layout', template.to_s))
      end

    def render(**hash)
#      puts "rendering layout"
        super(**(hash.merge(layout: nil)))
      end

  end
end
end
