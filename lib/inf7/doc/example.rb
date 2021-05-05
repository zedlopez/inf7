# coding: utf-8

module Inf7
  class Doc
    class Example
      include Inf7::DocUtil
      @examples = {}
      @examples_by_name = {}
      @examples_by_anchor = {}
      class << self
        attr_accessor :examples, :examples_by_name, :examples_by_anchor

        def [](num, name, target, content, section)
          num = num.to_i
          if Example.examples.key?(num)
            Example.examples[num].sources[section.chapter.volume.abbrev] = section
            Inf7::Doc.links["##{target}"] ||= { file: section.chapter.output_filename, anchor: "example-#{num}" } if section.chapter.volume.full_examples
            return Example.examples[num]
          end
          Example.new(num, name, target, content, section)
        end
        
        def process_block(html, section)
          exlist = []
          #      examples = html.sub!(/(<!-- START EXAMPLE.*<!-- END EXAMPLE -->)/m,'') ? $1 : nil
          html.scan(/<!-- START EXAMPLE "(\d+):\s+([^"]+)"\s+"([^"]+)"\s*-->\s*<a id="\3"><\/a>(.*?)<!-- END EXAMPLE -->/m).each do |a,b,c,d|
            exlist << Inf7::Doc::Example[a, b, c, d.gsub(%r{</p></blockquote>\s*<blockquote class="code">\s*<p class="quoted">}m,'</p><p class="quoted">'), section]
          end
          exlist
        end
      end

      attr_accessor :content, :sources, :node
      attr_reader :num, :name, :section, :target, :stars

      def linkback(link_format = :chapter)
        linkback_div = Inf7::Doc::Doc.create_element('div', class: 'linkback')
        @sources.each_pair do |abbrev,section|        
          linkback_div  << Inf7::Doc::Doc.create_element('a', section.header, href: (link_format != :chapter) ? "##{section.href}" : [ section.chapter.output_filename, section.href ].join('#'))
          linkback_div << Inf7::Doc::Doc.create_element('br') if linkback_div.children.count == 1
        end
        linkback_div
      end
      
      def full(output_format = :html, link_format = :chapter)
        @full[output_format].dup << @inner_div << linkback(link_format)
      end
      
      def initialize(num, name, target, content, section)
        @name = name
        @num = num.to_i
        @target = target
        content.gsub!(/"javascript:pasteCode\('([^']+)'\)"/) do |m|
          %Q{"javascript:copyCode(`#{Inf7::Doc.fix_javascript($1)}`)"}
        end
        @full = {}
        @node = Nokogiri::HTML::DocumentFragment.parse(content)
        egcuetext = @node.at_css('table.egcue tr td.egnamecell p.egcuetext')
        @stars= egcuetext.css('img.asterisk').count
        star_span = Inf7::Doc::Doc.create_element('span',('★' * @stars), class: 'example-difficulty')
        span = Inf7::Doc::Doc.create_element('span', "#{@num}. #{@name}", class: 'example-summary')
        @full[:html] = Inf7::Doc::Doc.create_element('details', class: 'full-example', id: "example-#{@num}")
        summary = Inf7::Doc::Doc.create_element('summary')
        summary << span.dup << " " << star_span.dup
        @full[:html] << summary
        @full[:epub] = Inf7::Doc::Doc.create_element('div', class: 'full-example', id: "example-#{@num}")
        @full[:epub] << span.dup << " " << star_span.dup
        
        inner_div = Inf7::Doc::Doc.create_element('div')
        inner_div.inner_html = @node.at_css('div.egpanel').inner_html.gsub(%r{</p></blockquote>\s*<blockquote class="code">\s*<p class="quoted">}m,'</p><p class="quoted">')
        @inner_div = unite_code(inner_div)
        @description = egcuetext.children.last.text.delete_prefix(@name).strip
        @sources = {}
        @sources[section.chapter.volume.abbrev] = section
        Inf7::Doc::Example.examples[@num] = self
        Example.examples_by_anchor[@target] = self
        index_name = @name.gsub(/[^\w\s]/,'').downcase

        Inf7::Doc::Example.examples_by_name[index_name] = self

        # TODO ugly hardcoded details
        if index_name.match(/^(?:a|the)\s+(.*)$/)
          Inf7::Doc::Example.examples_by_name[$1] = self
        end
        if index_name.match(/neighbourhood/)
          Inf7::Doc::Example.examples_by_name[index_name.sub(/neighbourhood/,'neighborhood')] = self
        end
        if index_name.match(/^(.*)\s+(?:1|i and ii|u|van winkle)$/)
          Inf7::Doc::Example.examples_by_name[$1] = self
        end
      end

      def onclick
        "(function() { document.getElementById('example-#{@num}').setAttribute('open','open'); return true; })();"
      end

      # TODO get rid of
     def link(linktext = nil)
       a = Inf7::Doc::Doc.create_element('a', linktext || @name, href: "##{@target}", class: 'example-link')
#       a[:href] = Inf7::Doc.links["##{@target}"][:chapter] #  if linktext
       a
     end
      
      def blurb(link_format = :chapter)
        example_div = Inf7::Doc::Doc.create_element('div',class: 'example-short', id: "example-short-#{@num}")
        example_p = Inf7::Doc::Doc.create_element('p', class: 'example-p')
        start = Inf7::Doc::Doc.create_element('span',  "#{@num}. ", class: "example-short-start")
        start << link
        example_p << start
        example_p << " "
        star_span = Inf7::Doc::Doc.create_element('span',('★' * @stars), class: 'example-difficulty')
        example_p << star_span
        example_p << " "
        desc = Inf7::Doc::Doc.create_element('span', @description, class: "example-description")
        example_p << " "
        example_p << desc
        other_section = sources['RB']
        example_p << " (c.f. "
        example_p << Inf7::Doc::Doc.create_element('a', other_section.header, href: "#{other_section.url(link_format)}")
        example_p << ")"
        example_div << example_p
        example_div
      end
    end
end


end
