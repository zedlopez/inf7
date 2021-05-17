#!/usr/bin/env ruby
# coding: utf-8

require 'inf7/conf'
require 'inf7/doc/section'
require 'inf7/doc/example'
require 'inf7/doc/chapter'
require 'inf7/doc/volume'
require 'tty-which'
require 'nokogiri'
require 'optimist'
require 'open3'
require 'erubi'
require 'cgi'

module Inf7
  class Doc

    Doc = Nokogiri::HTML("")
    BooksHash = { wi: { title: "Writing in Inform", abbrev: "WI", file_prefix: 'doc' },
              rb: { title: "Recipe Book", abbrev: "RB", file_prefix: 'Rdoc', full_examples: :full },
            }
    Books = BooksHash.values
              
    @links = {}
    class << self
      attr_accessor :links
      # Ruby 2.7+ blares warnings to STDERR about URI.escape's deprecation hence rolling our own
      def uri_escape(str)
        str.split(//).map {|c| c.match(URI::UNSAFE) ? sprintf('%%%02x',c.ord).upcase : c }.join
      end
      def uri_unescape(str)
        str.gsub(/%(\h\h)/, $1.to_s.to_i(16).chr)
      end
      def epub(options)
        Optimist.die "Can't find pandoc" unless TTY::Which.which('pandoc')
        %w{ metadata.yml epub.css}.each do |filename|
          Inf7::Template.write(filename, File.join(Inf7::Conf.doc, filename))
        end
        stdout, stderr, rc = Open3.capture3('pandoc', '-o', File.join(Inf7::Conf.doc,'inform7.epub'), File.join(Inf7::Conf.doc, 'metadata.yml'), File.join(Inf7::Conf.doc, 'epub.html'), '-t', 'epub3', "--epub-cover-image=#{File.join(Inf7::Conf.doc, %Q{Welcome Background.png})}", '--toc', "--css=#{File.join(Inf7::Conf.doc,'epub.css')}", '--toc-depth=3')
        if rc.exitstatus.zero?
          puts stdout # TODO respect quiet
        else
          STDERR.puts stderr
          exit rc.exitstatus
        end
      end

      def fix_javascript(js)
        Inf7::Doc.uri_unescape(js).gsub(/\[=(0x\h{4})=\]/) do |n|
          case $1
          when "0x0022"
            '&quot;'
          when "0x0027"
            '&apos;'
          when "0x000A"
            '\n'
          when "0x0009"
            '\t'
          else
            Integer($1).chr
          end
        end
      end
    
      def to_html(node, link_format = :chapter, output_format = :html)
        node = node.dup
        node.css('a').each do |a|
          unless a[:href]
            a.remove
            next
          end
          if a[:href].match(/^javascript/) and (:html != output_format)
            a.remove
            next
          end
          if a[:href].match(/^javascript:project/)
            a.remove
            next
          end          
          if a[:href].match(/(#.+)\Z/) and Inf7::Doc.links.key?($1)
            a[:href] = (:chapter == link_format) ? [ Inf7::Doc.links[$1][:file], Inf7::Doc.links[$1][:anchor]].join('#') : "##{Inf7::Doc.links[$1][:anchor]}"
          elsif Inf7::Doc.links.key?(a[:href])
            a[:href] = (:chapter == link_format) ?  [ Inf7::Doc.links[a[:href]][:file], Inf7::Doc.links[a[:href]][:anchor]].join('#') : "##{Inf7::Doc.links[a[:href]][:anchor]}"
          end
          a[:onClick] = Inf7::Doc::Example.examples[$1.to_i].onclick if a[:href].match(/#example-(\d+)\Z/) 
        end
        node.to_html
      end
      
      def dump
        File.open(File.join(Inf7::Conf.data, 'links.yml'), 'w') {|f| f.puts(YAML.dump(@links)) }
      end

      def load
        linksfile = File.join(Inf7::Conf.data, 'links.yml')
        @links = File.exist?(linksfile) ? YAML.load(File.read(linksfile)) : {}
      end

      def create(options)
        Optimist.die("Must run setup first") unless Inf7::Conf.conf
        if (options[:active])
          write_template_files
          return
        end
        Dir[File.join(Inf7::Conf.conf[:resources],'*.png')].each {|png| puts png; FileUtils.cp(png, Inf7::Conf.doc)}
        Dir[File.join(Inf7::Conf.conf[:resources],'*_images')].each {|dir| FileUtils.cp_r(dir, Inf7::Conf.doc) }
        Dir[File.join(Inf7::Conf.conf[:resources],'*_icons')].each {|dir| FileUtils.cp_r(dir, Inf7::Conf.doc) }
        Dir[File.join(Inf7::Conf.conf[:docs],'*.html')].each do |path|
          next if path.match(%r{/R?doc\d+\.html$})
          FileUtils.cp(path, Inf7::Conf.doc)
        end
        Inf7::Doc.new.process!(options)
      end

      def write_template_files
        Inf7::Template.write(:copycode, File.join(Inf7::Conf.doc, 'copycode.js'))
        Inf7::Template.write(:style, File.join(Inf7::Conf.doc, 'style.css'))
        Inf7::Template.write(:onejs, File.join(Inf7::Conf.doc, 'one.js'))
      end

      
    end

    def initialize
    end

    def general_index
      contents = File.read(File.join(Inf7::Conf.doc,"general_index.html"))
      contents.gsub!(%r{<a id="(l\d+)"></a><p class="indexentry">}m,'<p class="indexentry" id="\1">')
      
      doc = Nokogiri::HTML(contents)
      index = doc.create_element('div', class: 'general-index')
      doc.css('p.indexentry').each do |p|
        if p[:style]
          p[:style].match(/(\d+)em;$/)
          p[:class] = "#{p[:class]} indent#{$1.to_i/4}"
        end
        p.delete('style')
        p.xpath('.//a[starts-with(@href, "doc") and contains(text()," ex ")]').each do |wi_ex|
          wi_ex.next_sibling.remove
          wi_ex.remove
        end
        p.css('a').each do |a|
          next if a[:href].start_with?('#l')
          a.inner_html = "#{a[:href].start_with?('R') ? 'RB' : 'WI'} #{a.inner_html}"
        end
        p[:id] = p.previous[:id]
        index << p.dup
      end
      index
    end
    
    def process!(options)
      print "Importing docs" unless options[:quiet]
      Books.each {|b| Inf7::Doc::Volume[**b].parse_files(Inf7::Conf.conf[:docs], options[:quiet]); }
      Inf7::Doc::Volume.update!
      puts unless options[:quiet] # TODO neaten
      Inf7::Doc.dump
      print "Writing docs" unless options[:quiet]
      index = general_index
      Inf7::Doc.write_template_files
      Inf7::Template.write(:toc, File.join(Inf7::Conf.doc, 'index.html'), volumes: Inf7::Doc::Volume.volumes, index: Inf7::Doc.to_html(index, :chapter))
      
      chapter_tmpl = Inf7::Template[:chapter]
      Inf7::Doc::Volume.volumes.each do |vol|
        vol.chapters.values.each do |chapter|
          filename = File.join(Inf7::Conf.doc, chapter.output_filename)
          File.open(filename, 'w') do |f|
            f.puts(chapter_tmpl.render(chapter: chapter))
            print '.'  unless options[:quiet]
          end
        end
      end
      puts unless options[:quiet]

      Inf7::Template.write(:epub, File.join(Inf7::Conf.doc,'epub.html'), output_format: :epub, index: Inf7::Doc.to_html(index, :one), volumes: Inf7::Doc::Volume.volumes)
      output_filename = File.join(Inf7::Conf.doc,'one.html')
      Inf7::Template.write(:one, output_filename, output_format: :html, index: Inf7::Doc.to_html(index, :one), volumes: Inf7::Doc::Volume.volumes)
    end
  end  
end
