require 'inf7'
require 'inf7/doc'
require 'fileutils'
require 'yaml'
require 'xdg'

module Inf7
  class Conf
    xdg = XDG::Environment.new
    @dir = File.join(xdg.config_home, Inf7::Appname)
    @tmpl = File.join(@dir, 'tmpl')
    @data = File.join(xdg.data_home, Inf7::Appname)
    @doc = File.join(@data, 'doc')
    @cache = File.join(xdg.cache_home, Inf7::Appname)
    @doc_cache = File.join(@cache,'doc')
    [ @doc, @doc_cache, @tmpl ].each {|d| FileUtils.mkdir_p(d) }
    @file = File.join(@dir, 'inf7.yml')
    @conf = YAML.load(File.read(@file)) if File.exist?(@file)
    class << self
      attr_reader :dir, :file, :conf, :data, :cache, :doc, :doc_cache, :tmpl
      def [](x)
        raise RuntimeError.new("You must run setup first") unless File.exist?(@file)
        @conf[x]
      end

      def create(conf)
        raise RuntimeError.new("#{@file} already exists") if File.exist?(@file)
        @conf = conf
        File.open(@file, 'w') {|f| f.write(YAML.dump(conf))}
        %w{ story extension }.each do |template|
          dest = File.join(@tmpl, "#{template}.erb")
          FileUtils.cp(Inf7::Template.path(template), dest) unless File.exist?(dest)
        end
#        story_template = File.join(@dir, 'story.ni.erb')
#        File.open(story_template, 'w') {|f| f.write(Inf7::Project::StoryTemplate) } unless File.exist?(story_template)
        FileUtils.mkdir_p(File.join(@dir, 'extensions'))
        Inf7::Doc.create(conf)
      end
    end
    
    def initialize
    end      
  end
end
