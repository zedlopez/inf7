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
    @bin = File.join(@data, 'bin')
    [ @doc, @tmpl, @ext, @archives, @bin ].each {|d| FileUtils.mkdir_p(d) }
    @file = File.join(@dir, 'inf7.yml')
    @conf = YAML.load(File.read(@file)) if File.exist?(@file)
    class << self
      attr_reader :dir, :file, :conf, :data, :doc, :tmpl, :ext
      def [](x)
        raise RuntimeError.new("You must run setup first") unless File.exist?(@file)
        @conf[x]
      end

      def absolutify(hash)
        # ensure we have absolute paths
        
        %i{ internal external docs resources cheap_glulx cheap_zcode i7tohtml gterp zterp browser ni inform6 cblorb }.each do |dir_sym|
          next unless hash.key?(dir_sym)
          hash[dir_sym] = (Pathname.new(hash[dir_sym]).expand_path).to_s
        end
        hash
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

      def fetch_and_save(uri, output_file)
        unless File.exist?(output_file) and !File.size(output_file).zero?
          download = fetch(hash[:url])
          raise RuntimeError.new("Couldn't download #{hash[:url]}") unless download
          File.open(output_file, 'w') {|f| f.write(download) }
        end
      end

      def download
        Inf7::Downloads.each_pair do |label, hash|
          next if (:cli == label) and 
          output_file = File.join(@archives, hash[:dest])
        end
        label = :data
        
        output_file = File.join(@archives, Inf7::Downloads[:data][:dest])
        fetch_and_save(Inf7::Downloads[:data][:url], output_file)
        Dir.mktmpdir do |tmpdir|
          stdout, stderr, rc = Open3.capture3('tar', 'x', '-C', tmpdir, '-f', output_file)
          @conf[:internal] = File.join(@data, 'Internal') # don't mkdir_p it
          FileUtils.cp_r(tmpdir, @conf[:internal])
        end
        @conf[:resources] = File.join(@conf[:internal], 'Resources')
        @conf[:docs] = File.join(@conf[:internal], 'Documentation')

        @conf[:arch] ||= Inf7::Project::Defaults[:arch]
        output_file = File.join(@archives, Inf7::Downloads[:cli][:dest])
        fetch_and_save(Inf7::Downloads[:cli][:url], output_file)
        Dir.mktmpdir do |tmpdir|
          stdout, stderr, rc = Open3.capture3('tar', 'x', '-C', tmpdir, '-f', output_file)
          inform7_dir = File.join(tmpdir, "inform7-#{Inf7::I7_version}")
          raise RuntimeError.new("#{stderr} untarring #{output_file}") unless rc.exitstatus.zero?

            %w{ compilers interpreters }.each do |subarchive|
              tar_archive = "inform7-#{subarchive}_#{Inf7::I7_version}_#{@conf[:arch]}.tar.gz"
              Dir.mktmpdir do |subtmpdir|
                stdout, stderr, rc = Open3.capture3('tar', 'x', '-C', subtmpdir, '-f', File.join(inform7_dir, tar_archive))
                raise RuntimeError.new("#{stderr} untarring #{output_file}") unless rc.exitstatus.zero?
                Dir[File.join(subtmpdir, 'share', 'inform7', subarchive.capitalize, '*')].each do |file|
                  FileUtils.cp(file, @bin)
                end
              end
            end
          end

        if 'Linux' == `uname`.rstrip
          %w{ ni inform6 cBlorb }.each{ |file| @conf[file.downcase.to_sym] ||= File.join(@bin, file) }
          @conf[:cheap_glulx] ||= File.join(@bin, 'dumb-glulxe')
          @conf[:cheap_zcode] ||= File.join(@bin, 'dumb-frotz')
        end
        @conf.delete(:download) # so it's not written to inf7.yml
      end
      
      def create(conf)
        raise RuntimeError.new("#{@file} already exists") if File.exist?(@file)
        @conf = conf
        raise RuntimeError.new("$HOME not set; you must specify --external") unless @conf.key?(:external) or ENV.key?('HOME')
        @conf[:external] ||= File.join(ENV['HOME'], 'Inform')
        raise RuntimeError.new("#{@conf[:external]} must be a writable directory") unless Dir.exist?(@conf[:external]) and File.writable?(@conf[:external])
        download if @conf[:download]

        @conf = Inf7::Conf.absolutify(@conf)
        
        File.open(@file, 'w') {|f| f.write(YAML.dump(conf))}
        %w{ story extension }.each do |template|
          dest = File.join(@tmpl, "#{template}.erb")
          FileUtils.cp(Inf7::Template.path(template), dest) unless File.exist?(dest)
        end
        FileUtils.mkdir_p(File.join(@dir, 'extensions'))
        Inf7::Doc.create(@conf)
        Inf7::Project.census(@conf)
      end
    end
    
    def initialize
    end      
  end
end
