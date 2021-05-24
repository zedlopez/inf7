require 'inf7'
require 'inf7/doc'
require 'fileutils'
require 'yaml'
require 'zlib'
require 'xdg'

module Inf7
  class Conf
    xdg = XDG::Environment.new
    @dir = File.join(xdg.config_home, Inf7::Appname)
    @tmpl = File.join(@dir, 'tmpl')
    @data = File.join(xdg.data_home, Inf7::Appname)
    @archives = File.join(@data, 'archives')
    @doc = File.join(@data, 'doc')
    @ext = File.join(@data, 'ext')
    [ @doc, @tmpl, @ext, @archives ].each {|d| FileUtils.mkdir_p(d) }
    @file = File.join(@dir, 'inf7.yml')
    @conf = YAML.load(File.read(@file)) if File.exist?(@file)
    class << self
      attr_reader :dir, :file, :conf, :data, :doc, :tmpl, :ext
      def [](x)
        raise RuntimeError.new("You must run setup first") unless File.exist?(@file)
        @conf[x]
      end

      def fetch(uri_str, limit = 10)
        raise ArgumentError, 'too many HTTP redirects' if limit.zero?
        response = Net::HTTP.get_response(URI(uri_str))
        case response
        when Net::HTTPSuccess then
          return response.body
        when Net::HTTPRedirection then
          location = response['location']
          return fetch(location, limit - 1)
        else
          raise RuntimeError.new("Got #{response.class} trying to download #{uri_str}")
        end
      end

      def download
        Inf7::Downloads.each_pair do |label, hash|
          next if (:cli == label) and 'Linux' != `uname`.rstrip
          output_file = File.join(@archives, hash[:dest])
          unless File.exist?(output_file) and !File.size(output_file).zero?
            download = fetch(hash[:url])
            raise RuntimeError.new("Couldn't download #{hash[:url]}") unless download
            File.open(output_file, 'w') {|f| f.write(download) }
          end
        end
        label = :data
        output_file = File.join(@archives, Inf7::Downloads[label][:dest])
          #          Dir.mktmpdir do |tmpdir|
          tmpdir = File.join(@data, 'tmp', label.to_s)
          FileUtils.mkdir_p(tmpdir)
          puts tmpdir
            stdout, stderr, rc = Open3.capture3('tar', 'x', '-C', tmpdir, '-f', output_file)
            raise RuntimeError.new("#{stderr} untarring #{output_file}") unless rc.exitstatus.zero?
            %w{ Extensions Documentation Resources }.each do |dir|
              dest_dir = File.join(@data, 'Internal')
              FileUtils.mkdir_p(dest_dir)
              FileUtils.cp_r(File.join(tmpdir, dir), dest_dir)
            end
            
#          end
      end
      
      def create(conf)
#        raise RuntimeError.new("#{@file} already exists") if File.exist?(@file)
        @conf = conf
        download if @conf[:download]
        exit

        
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
