module Inf7
  class Doc
    class Chapter
      include Inf7::DocUtil
    attr_reader :volume, :num, :href, :title
    attr_accessor :sections

    def initialize(title, num, volume)
      @title = title
      @num = num
      @volume = volume
      @sections = {}
      @volume.chapters[@num] = self
      @href = anchorify(volume.abbrev, 'chapter', @num, @title)
    end

    def previous
      (num > 1) ? @volume.chapters[@num-1] : nil
    end

    def subsequent
      (num < @volume.chapters.count) ? @volume.chapters[@num+1] : nil
    end
    
    def output_filename
      "#{[ @volume.abbrev.downcase, @num ].join('_')}.html"
    end
    
#     def node(single = true)
#       @node = Inf7::Doc::Doc.create_element('section', class: 'chapter', id: @href)
#       @node << Inf7::Doc::Doc.create_element('h2', "Chapter #{@num}. #{@title}") unless single
#       official_div =Inf7::Doc::Doc.create_element('div', class: 'official')
#       official_div << Inf7::Doc::Doc.create_element('a', "Inform 7 website's #{@volume.title} Chapter #{@num}", href: @sections[1].inform7link, class: "official")
# #      @node << official_div
#       @sections.sort_by {|k,v| k }.each {|k,v| @node << v.div.to_html }
#       @node
#     end

    def url(single = true)
      single ? "#{output_filename}##{href}" : href
    end

#    def link(single = true)
#      Inf7::Doc::Doc.create_element('a', header, href: url(single))
#    end
    
    def header
      "#{@num}. #{@title}"
    end

  end

end
end
