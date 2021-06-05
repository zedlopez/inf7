require 'open3'
require 'pp'

module Inf7
  class Source

    def content
      @content ||= File.read(@filename)
    end

    def lines
      content.split($/)
    end

    def preprocess

    end
    
    def pretty_print(i7tohtml, string: content)
      return string.split($/) unless i7tohtml
      stdout, stderr, rc = Open3.capture3(i7tohtml, @filename, :stdin_data => string)
      if rc.exitstatus and rc.exitstatus.zero? # on SIGSEGV exitstatus is nil
        result = stdout.split($/)
      else
        STDERR.puts "Failed"
        STDERR.puts(stdout) if stdout
        STDERR.puts(stderr) if stderr
        raise RuntimeError.new("error running #{i7tohtml}")
      end
      return result
    end

    
    # does not test for existence
    def initialize(filename, content: nil)
      @pathname = Pathname.new(filename)
      @filename = @pathname.expand_path.to_s
      @content = content if content
      return true
    end

    def write(destination = @filename)
      raise RuntimeError.new("Can't write source with no content") unless @content
      File.open(destination, 'w') {|f| f.write(@content) }
    end

    def with_suffix(suffix, mode, downcase: false)
      filename = "#{@ext_name}.#{suffix}"
      result = case mode
               when :author
                 File.join(@author_dir, filename)
               when :full
                 @filename
               else
                 filename
               end
      downcase ? result.downcase : result
    end

  end
end
