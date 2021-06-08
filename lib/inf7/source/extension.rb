module Inf7
  class Extension < Source

    attr_accessor :author_dir, :ext_name, :filename, :extension_dir
    def initialize(filename)
      super(filename)
      through_auth, ext_name = @pathname.split
      extension_dir, author_dir = through_auth.split
      @extension_dir = extension_dir.to_s
      @author_dir = author_dir.to_s
      @ext_name = ext_name.to_s.gsub(/\..*\Z/,'')
    end

    def documentation
      get_doc_and_code unless @documentation
      @documentation
    end

    def code
      get_doc_and_code unless @code
      @code
    end

    def example_pasties
      get_doc_and_code unless @example_pasties
      @example_pasties
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

    def pp_html(standalone: false)
      Inf7::Template[standalone ? :standalone_extension : :extension_source].render(ext: self)
    end
    
    def i7x(mode, downcase: false)
      with_suffix(:i7x, mode, downcase: downcase)
    end

    def html(mode, downcase: false)
      with_suffix(:html, mode, downcase: downcase)
    end

#    def pretty_print(i7tohtml = nil)
#      super(i7tohtml, source_lines: documentation + code)
#    end
      
    def get_doc_and_code(i7tohtml = nil)
      i7tohtml ||= Inf7::Source.check_executable(Inf7::Conf.conf[:i7tohtml])
      in_doc = false
      in_example = false
      example_pasties = []

      lines.each do |line|
        in_doc = true if line.strip.match(/----\s+documentation\s+----/i)
        if in_doc and line.match(/\A\s*\*:(.*)\Z/)
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
      pp_lines = pretty_print(i7tohtml)

      results = { doc: [], code: [] }
      in_doc = false
      pp_lines.each do |line|
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
