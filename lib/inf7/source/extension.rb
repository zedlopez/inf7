module Inf7
  class Extension < Source

    attr_accessor :author_dir, :ext_name, :filename, :extension_dir
    def initialize(filename)
      super(filename)
      through_auth, ext_name = @pathname.split
      extension_dir, author_dir = through_auth.split
      @extension_dir = extension_dir.to_s
      @author_dir = author_dir.to_s
      @ext_name = ext_name.to_s.gsub(/\..*\Z/,'') # strip .suffix
    end

    def ubiquitous?
      ('Graham Nelson' == @author_dir) and (("Standard Rules" == @ext_name) or ("English Language" == @ext_name))
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

    def pp_html(standalone: false, **h)
      Inf7::Template[standalone ? :standalone_extension : :extension_source].render(ext: self, **h)
    end
    
    def i7x(mode, downcase: false)
      with_suffix(:i7x, mode, downcase: downcase)
    end

    def html(mode, downcase: false)
      with_suffix(:html, mode, downcase: downcase)
    end
    
    def get_doc_and_code(i7tohtml = nil, standalone: false)
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
      results[:doc][0] = results[:code][0].sub(/\s+begins\s+here\s*\./,'').sub('>', ">#{ (results[:doc].empty? or (results[:doc].count == 1)) ? 'No d' : 'D' }ocumentation for ")
      results[:code].pop until results[:code][-1].match(/\S/)
      @documentation = results[:doc]
      @code = results[:code]
      @example_pasties = example_pasties
      return results[:doc], results[:code], example_pasties
    end

    class StandardRules < Extension
      include Inf7::DocUtil
      def get_doc_and_code(i7tohtml = nil, standalone: false)
        unless @documented_at
          hierarch, @documented_at = build_hierarchy(standalone: standalone)
        end
        @toc = toc(hierarch) unless @toc
        super
        code_lines = []
        @code.each do |code_line|
          if code_line.match(/documented\s+at\s+([-_\w]+)/)
            ref = $1
            code_line.sub!(ref, @documented_at[ref])
          end
          code_lines << code_line
        end
        @code = code_lines
    end
      
      def write_html(dest_dir_root, i7tohtml)
        hierarch, @documented_at = build_hierarchy(standalone: false)
        @toc = toc(hierarch)
      Inf7::Template.write(:extension_source, formatted_path(dest_dir_root), ext: self, toc: @toc)
    end

    def pp_html(standalone:  false)
      get_doc_and_code(standalone: standalone)
      if standalone
        header =               '<h1 style="text-align: center;">Standard Rules by Graham Nelson</h1>
        <h2 style="text-align: center;">Version 3/120430 for <a href="http://inform7.com/">Inform 7</a> 6M62</h2>
        <div>The Standard Rules are &copy; Graham Nelson and published under the <a href="https://github.com/zedlopez/standard_rules/blob/main/LICENSE.md">Artistic License 2.0</a>.</div>'

        Inf7::Template[:standalone_extension].render(ext: self, toc: @toc, header: header)
      else
        Inf7::Template[:extension_source].render(ext: self)
      end
    end


      private
      def toc(hierarch)
        toc_lines = []
        toc_lines << %Q{<div class="toc" style="margin: 3rem;">}
        hierarch.each_pair do |part, part_hash|
          toc_lines << "<details><summary><strong>#{part}</strong></summary><ul>"
          part_hash[:sections].each_pair do |section, sect_hash|
            unless sect_hash.key?(:subsections)
              toc_lines << %Q{<li>#{section}. <a href="#line#{sect_hash[:line]}">#{sect_hash[:name]}</a></li>}
              unless sect_hash[:actions].empty?
                toc_lines << "<details><summary>Actions</summary><ul>"
                sect_hash[:actions].each_pair do |action, line|
                  toc_lines << %Q{<li><a href="#line#{line}">#{action}</a></li>}
                end
                toc_lines << "</ul></details>"
              end
            else
              toc_lines << %Q{<details><summary>#{section}. #{sect_hash[:name]}</summary><ul>}
              sect_hash[:subsections].each_pair do |sub_sect, sub_sect_hash|
                toc_lines << %Q{<li><a href="#line#{sub_sect_hash[:line]}">#{sub_sect} #{sub_sect_hash[:name]}</a></li>}
              end
              toc_lines << "</ul></details>"
            end
          end
          toc_lines << "</ul></details>"
        end
        toc_lines << "</div>"
        toc_lines.join($/)
      end

      def build_hierarchy(standalone: false)
        hash = {}

        hierarch = {}
        cur_part = nil
        cur_sect = nil
        cur_sub_sect = nil
        wi = Inf7::Doc::Volume.new(abbrev: 'WI')

        
        lines.dup.each.with_index(1) do |line, i|
          case line
          when /\ADocument\s+(.*)\s+at\s+(\S+)\s+"([^"]+)"\s+"([^"]+)"\.\Z/
            doc, ch_sect, ch_sect_w_name = $2, $3, $4
            refs = $1.split(/\s+/)
            ch, sect = ch_sect.split(/\./)
            chapter = Inf7::Doc::Chapter.new('', ch, wi)
            refs.each {|r| hash[r] =
                       %Q{<a href="#{ standalone ? inform7link('WI', ch, sect) : [ Inf7::Conf.doc, chapter.url(section_num: sect) ].join('/') }">#{r}</a>}}
          when /\A(Part)/
            hierarch[ line.chomp ] = { line: i, sections: {}}
            cur_part = line.chomp 
          when /\ASection(?:[^\/]+)\/(\S+)\s+\-\s+(.*)\Z/
            raw_sect = $1
            name = $2
            if raw_sect.match(/(\d+)\/(\d+)/)
              cur_sect = $1
              sub_sect = $2
              cur_sub_sect = sub_sect
              name.match(/\A(.*?)\s+-\s+(.*)/)
              cur_sect_name = $1
              sub_sect_name = $2
              hierarch[cur_part][:sections][cur_sect] ||= { subsections: {}, line: i, name: cur_sect_name }
              hierarch[cur_part][:sections][cur_sect][:subsections][cur_sub_sect] = { name: sub_sect_name, actions: {}, line: i }
            else
              cur_sect = raw_sect
              hierarch[cur_part][:sections][cur_sect] = { name: name, actions: {}, line: i}
            end
            
          when /\A(.*?)\s+is an action (?:applying|out of world)/
            if cur_sub_sect
              hierarch[cur_part][:sections][cur_sect][:subsections][cur_sub_sect][:actions][$1] = { line: i }
            else
              hierarch[cur_part][:sections][cur_sect][:actions][$1] = i
            end
          end
        end

        return hierarch, hash
      end
      
    end
    
  end  
end
