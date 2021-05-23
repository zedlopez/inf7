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
    @ext = File.join(@data, 'ext')
    [ @doc, @tmpl, @ext ].each {|d| FileUtils.mkdir_p(d) }
    @file = File.join(@dir, 'inf7.yml')
    @conf = YAML.load(File.read(@file)) if File.exist?(@file)
    class << self
      attr_reader :dir, :file, :conf, :data, :doc, :tmpl, :ext
      def [](x)
        raise RuntimeError.new("You must run setup first") unless File.exist?(@file)
        @conf[x]
      end

      def create(conf)
        raise RuntimeError.new("#{@file} already exists") if File.exist?(@file)
        @conf = conf
        %i{ internal external docs resources }.each do |dir_sym|
          conf[dir_sym] = Pathname.new(conf[dir_sym]).expand_path.to_s
        end
        File.open(@file, 'w') {|f| f.write(YAML.dump(conf))}
        %w{ story extension }.each do |template|
          dest = File.join(@tmpl, "#{template}.erb")
          FileUtils.cp(Inf7::Template.path(template), dest) unless File.exist?(dest)
        end
        FileUtils.mkdir_p(File.join(@dir, 'extensions'))
        Inf7::Doc.create(conf)
      end
    end
    
    def initialize
    end      
  end
end
