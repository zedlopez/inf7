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
      Inf7::Doc.links["##{@href}"] = { file: output_filename, anchor: @href }
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

    def url(single = true, section_num: nil)
      return "#{output_filename}##{@volume.abbrev.downcase}-#{@num}.#{section_num}" if section_num
      single ? "#{output_filename}##{href}" : href
    end

    def header
      "#{@num}. #{@title}"
    end

  end

end
end
