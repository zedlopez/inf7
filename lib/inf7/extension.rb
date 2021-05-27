module Inf7
  class Extension < Source

    attr_accessor :author_dir, :ext_name, :filename
    def initialize(filename)
      super(filename)
      author_dir, ext_name = @pathname.split[-2,2]
      @author_dir = author_dir.basename.to_s
      @ext_name = ext_name.to_s.gsub(/\..*\Z/,'')
    end

    def i7x(mode, downcase: false)
      with_suffix(:i7x, mode, downcase)
    end

    def html(mode, downcase: false)
      with_suffix(:html, mode, downcase)
    end

    def get_doc_and_code(i7tohtml)
      raw = contents.split($/)
      in_doc = false
      in_example = false
      example_pasties = []
      raw.each do |line|
        in_doc = true if line.strip.match(/----\s+documentation\s+----/i)
        next unless in_doc
        if line.match(/\A\s*\*:(.*)\Z/)
          in_example = true
          example_pasties << [$1]
        elsif in_example
          if line.match(/\S/) and !line.start_with?("\t")
            in_example = false
          else
            example_pasties.last << line
          end
        end
      end
      lines = pretty_print(i7tohtml)
      results = { doc: [], code: [] }
      in_doc = false
      lines.each do |line|
        in_doc = true if line.strip.match(/----\s+documentation\s+----/i)
        results[ in_doc ? :doc : :code] << line
      end
      results[:code][0] = %Q{<span class="i7gh">#{results[:code][0]}</span>} unless results[:code][0].start_with?('<')
      # We only get "No documentation for..." if ---- Documentation ---- is absent even if the documentation has no lines
      results[:doc][0] = results[:code][0].sub(/\s+begins\s+here\s*\./,'').sub('>', ">#{ results[:doc].empty? ? 'No d' : 'D' }ocumentation for ")
      results[:code].pop until results[:code][-1].match(/\S/)
      return results[:doc], results[:code], example_pasties
    end
  end  
end
