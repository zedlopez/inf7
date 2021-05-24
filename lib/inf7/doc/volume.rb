module Inf7
  class Doc
    class Volume
  include Inf7::DocUtil
    @volumes = []
    @chapter_regexps = Hash.new {|h,k| h[k] = [] }

    class << self
      def [](**x)
        Volume.new(x)
      end
      def update!
        wi = @volumes.find {|v| 'WI' == v.abbrev }
        wi.chapters.values.each do |chapter|
          @chapter_regexps[chapter.num] << %r{chapter\s+#{chapter.num}[\.\s,]}i
          @chapter_regexps[chapter.num] << %r{chapter\s+on\s+"?#{chapter.title}"?}i
          @chapter_regexps[chapter.num] << %r{"?#{chapter.title}"? chapter}i
        end
        @chapter_regexps[wi.chapters.keys.max] << %r{final chapter of the documentation}
        @volumes.each {|vol| vol.chapters.values.each {|ch| ch.sections.values.each {|s| s.update! } } }
      end
      attr_accessor :volumes, :chapter_regexps
    end
    attr_accessor :chapters
    attr_reader :abbrev, :title, :file_prefix, :full_examples
    def initialize(title: nil, abbrev: nil, file_prefix: nil, full_examples: false)
      @title = title
      @abbrev = abbrev
      @file_prefix = file_prefix
      @chapters = {}
      @full_examples = full_examples
      Inf7::Doc::Volume.volumes << self
    end
    
    def parse_files(dir='.', quiet = nil)
      Dir[File.join(dir,"#{@file_prefix}*.html")].each do |filename|
        section = Inf7::Doc::Section[filename, self]
        print '.' if !quiet and (1 == section.num)
      end
    end

    def other
      Volume.volumes.find {|v| v != self }
    end
    end
  end

end
