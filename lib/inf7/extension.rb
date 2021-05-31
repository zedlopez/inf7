module Inf7
  class Extension < Source

    attr_accessor :author_dir, :ext_name, :filename, :documentation, :code, :example_pasties, :extension_dir
    def initialize(filename)
      super(filename)
      through_auth, ext_name = @pathname.split
      extension_dir, author_dir = through_auth.split
      @extension_dir = extension_dir.to_s
      @author_dir = author_dir.to_s
      @ext_name = ext_name.to_s.gsub(/\..*\Z/,'')
    end

    def name
      "#{@ext_name} by #{@author_dir}"
    end

    def formatted_path(dest_dir_root)
      dest_dir = File.join(dest_dir_root, @extension_dir)
      FileUtils.mkdir_p(dest_dir)
      File.join(dest_dir, html(:author, downcase: true))
    end
    
    def write_html(dest_dir_root, i7tohtml)
      get_doc_and_code(i7tohtml)
      Inf7::Template.write(:extension_source, formatted_path(dest_dir_root), ext: self)
    end

    def i7x(mode, downcase: false)
      with_suffix(:i7x, mode, downcase: downcase)
    end

    def html(mode, downcase: false)
      with_suffix(:html, mode, downcase: downcase)
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
      @documentation = results[:doc]
      @code = results[:code]
      @example_pasties = example_pasties
      return results[:doc], results[:code], example_pasties
    end
  end  
end
