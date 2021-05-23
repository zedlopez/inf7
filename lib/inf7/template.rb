require 'ostruct'
require 'fileutils'
require 'inf7/docutil'

module Inf7
  class Template
    include Inf7::DocUtil
    class << self

      def write(template_name, output_filename, **h)
        FileUtils.mkdir_p(File.dirname(output_filename))
        File.open(output_filename, 'w') do |f|
          f.write(Inf7::Template[template_name].render(**h))
        end
      end

      def path(template_name)
        conf_tmpl = File.join(Inf7::Conf.tmpl, "#{template_name}.erb")
        return File.expand_path(conf_tmpl) if File.exist?(conf_tmpl)
        File.expand_path("../../../tmpl/#{template_name}.erb", __FILE__)
      end

      def read(template_name)
        File.read(path(template_name))
      end
      
      def [](template_name)
        Template.new(template_name)
      end
    end
    def initialize(template)
      raise ArgumentError.new("Must specify non-empty string") unless template and !template.empty?
      @template = template
      @erubi = Erubi::Engine.new(Inf7::Template.read(@template), escape: true)
    end

    def render(**hash)
      context = OpenStruct.new(hash).instance_eval { binding }
      eval(@erubi.src, context)
    end
  end
end
