# coding: utf-8

require 'inf7/docutil'

module Inf7
  class Doc
    class Section
      include Inf7::DocUtil
      attr_reader :chapter, :num, :filename, :href, :title, :div, :volume, :output_filename

      class << self
        def [](filename,volume)
          slurp = File.read(filename)
          html = slurp.match(/(<!-- SEARCH.*)<div class="bookfooter">/m).captures.first
          Section.new(html, filename, volume)
        end
      end

      def url(link_format = :chapter)
        (:chapter == link_format) ? "#{chapter.output_filename}##{href}" : "##{href}"
      end

      def update!
        @div.xpath('.//a[not(text())]').each {|a|  a.remove }
        # TODO generalize. right now, chapter only
        if chapter.volume.full_examples
          @div.css('span.boldface').each do |span|
            name = CGI.unescapeHTML(span.inner_html).strip
            index_name = name.gsub(/[^\w\s]/,'').downcase
            if Inf7::Doc::Example.examples_by_name.key?(index_name)
              replacement = span.replace(Inf7::Doc::Example.examples_by_name[index_name].link(name))
              replacement.next= Inf7::Doc::Doc.create_element('span',' '+('★' * Inf7::Doc::Example.examples_by_name[index_name].stars), class: 'example-difficulty')
            end
          end
        end
        @div.xpath('.//img[@alt = "asterisk.png"]').each do |img|
          img.replace(Inf7::Doc::Doc.create_element('span',('★'), class: 'example-difficulty'))
        end
        { 'span.boldface' => 'strong', 'span.italic' => 'em', 'b'=>'strong','i' => 'em' }.each_pair do |k,v|
          @div.css(k).each {|b| s = Inf7::Doc::Doc.create_element(v); s.inner_html = b.inner_html; b.replace(s) }
        end
        @div.xpath('.//comment()').remove #each { |comment| comment.remove }

        # remove blockquote and p tags that are empty or contain only whitespace
        %w{ p blockquote }.each do |nodename|
          @div.xpath(%Q{.//#{nodename}[not(*) and not(text()[normalize-space()])]}).each do |node|
            node.remove
          end
        end      
        # TODO improve the aim here. only if p is first child of blockquote.code
        @div.xpath(%Q{.//p[@class = "quoted" and starts-with(text(), "\n \u00A0\u00A0")]}).each do |p|
          next unless p.inner_text.match(/^\n \u00A0\u00A0\s+"/)
          p.inner_html = p.inner_html.sub(/^\n \u00A0\u00A0\s+"/,'"')
        end
        @div.xpath(%Q{.//p[not(@class = "quoted") and contains(text(), "hapter")]}).each do |p|
          wi = Inf7::Doc::Volume.volumes.find {|v| 'WI' == v.abbrev }
          # go in reverse order to be sure to process longer before shorter, e.g., Chapter 27 before Chapter 2
          Inf7::Doc::Volume.chapter_regexps.keys.sort.reverse.each do |chapter_num|
            regexps = Inf7::Doc::Volume.chapter_regexps[chapter_num].dup
            Inf7::Doc::Volume.chapter_regexps[chapter_num].each do |regexp|
              p.inner_html = p.inner_html.gsub(regexp) do |match|
                Inf7::Doc::Doc.create_element('a', match, href: "##{wi.chapters[chapter_num].href}").to_html
              end
              # RB has literally no instances of 'next|previous chapter'
              # or this would make bad links for them
              if @chapter.num > 1
                prev_link = Inf7::Doc::Doc.create_element('a', 'previous chapter', href: "##{wi.chapters[@chapter.num-1].href}").to_html
                p.inner_html = p.inner_html.gsub(/\bprevious chapter\b/i, prev_link)
              end
              if wi.chapters.key?(@chapter.num+1)
                next_link = Inf7::Doc::Doc.create_element('a', 'next chapter', href: "##{wi.chapters[@chapter.num+1].href}").to_html
                p.inner_html = p.inner_html.gsub(/\b((?:this\s+)?next chapter)\b/i) do |match|
                  match.downcase.start_with?('this') ? match : next_link
                end
              end
            end
          end
        end
      end
      
      def initialize(html, filename, volume)
        html.gsub!(%r{<a id="c\d+(_\d+)?"></a>}m,'')
        html.gsub!(%r{<div class="definition"><a id="(defn\d+)"></a>}m,'<div class="definition" id="\1">')
        html.gsub!(%r{</table><blockquote><p>\s+</p></blockquote>},'</table>')

        @node = Nokogiri::HTML::DocumentFragment.parse(html)
        
        @node.xpath('.//img[starts-with(@src, "inform:/")]').each {|img| img[:src] = img[:src].delete_prefix('inform:/') }
        @filename = File.basename(filename)
        @volume = volume
        
        @title = @node.at_xpath("./comment()[starts-with(.,' SEARCH TITLE')]").text.match(/^\s*search\s+\S+\s+"(.*)"\s*$/i).captures.first
        chapter_dot_section = @node.at_xpath("./comment()[starts-with(.,' SEARCH SECTION')]").text.match(/^\s*search\s+\S+\s+"(.*)"\s*$/i).captures.first
        chapter_num, @num = chapter_dot_section.split(/\./).map(&:to_i)
        @chapter = volume.chapters[chapter_num] || Inf7::Doc::Chapter.new(@node.at_css('div.bookheader table.midnightblack span.midnightbannertext').inner_html.match(/^Chapter\s+\d+:\s+(.*)/).captures.first, chapter_num, volume)
        @chapter.sections[@num] = self
        @href = anchorify(label) # need @chapter first
        Inf7::Doc.links[@filename] = { file: chapter.output_filename, anchor: @href }

        @node.xpath('./div[starts-with(@id,"defn")]').each do |div|
          Inf7::Doc.links["##{div[:id]}"] = { file: chapter.output_filename, anchor: div[:id] }
        end

        @node.at_css('div.bookheader').remove
        @node.css('hr').remove
        @node.inner_html= @node.inner_html.gsub(%r{</p></blockquote>\s*<blockquote class="code">\s*<p class="quoted">}m,'</p><p class="quoted">')
        @examples = []
        @node.xpath('.//a[starts-with(@href, "javascript:createNewProject")]').remove
        if bookexamples = @node.at_css('div.bookexamples')
          @examples = Inf7::Doc::Example.process_block(bookexamples.inner_html, self)
          bookexamples.remove
        end
        @node.xpath('.//a[starts-with(@href, "javascript")]').remove
        sectionheading = @node.at_css('p.sectionheading')
        @node.css('p.sectionheading').each do |p|
          h3 = Inf7::Doc::Doc.create_element('h3', header)
          p.replace(h3)
        end
        @xrefs = nil
        @node.css('p.crossreference').each do |xref|
          unless @xrefs
            @xrefs = Inf7::Doc::Doc.create_element('div', class: 'crossreferences')
            @xrefs << Inf7::Doc::Doc.create_element('h4',"See also")
          end
          xref.css('img.asterisk').each {|i| i.remove }
          linkcontent_div = Inf7::Doc::Doc.create_element('div',class: 'crossreference') 
          a = xref.at_css('a')
          a.inner_html = a.at_css('b').inner_html
          a[:class] = 'crossreference_link'
          linkcontent_div << a
          ending = xref.children.last
          linkcontent_div << ((ending.name == 'i') ? Inf7::Doc::Doc.create_text_node(ending.inner_html.gsub(/<[^>]+?>/,'')) : ending.clone)
          @xrefs << linkcontent_div
          xref.remove
        end
        
        @div = Inf7::Doc::Doc.create_element('section', class: 'section', id: @href)
        @node = unite_code(@node)
        @div << @node
        @div << @xrefs if @xrefs
      end

      def header
        "#{@volume.abbrev} §#{@chapter.num}.#{num}. #{@title}"
      end

      def label
        "#{@volume.abbrev} #{@chapter.num}.#{num}"
      end

      def inform7link(vol = @volume.abbrev, ch = @chapter.rum, sect = @num)
        "http://inform7.com/book/#{vol}_#{ch}_#{sect}.html"
      end

      def to_html(link_format = :chapter, output_format = :html)
#        puts "section #{output_format}"
        div = @div.dup
        unless @examples.empty?
          example_block_div = Inf7::Doc::Doc.create_element('div',class: "section-example-block")
          example_block_div << Inf7::Doc::Doc.create_element('h4',"Examples")
          @examples.each do |example|
            example_block_div << (@chapter.volume.full_examples ? example.full(output_format, link_format) :  example.blurb(link_format))
           end
          div << example_block_div
        end
        Inf7::Doc.to_html(div, link_format, output_format)
      end

    end
  end
end
