module Inf7
  class Page < Template

    def initialize(template: nil, layout: 'default')
      @content_template = Inf7::Template[template] if template
      @layout = Inf7::Template::Layout.new(layout)
    end

    def render(**hash)
      hash[:content] ||= @content_template.render(**hash)
      @layout.render(**hash)
    end
  end
end
