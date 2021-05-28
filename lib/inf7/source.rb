require 'open3'

module Inf7
  class Source

    def contents
      @contents ||= File.read(@filename)
    end

    def lines
      @contents.split($/)
    end
    def pretty_print(i7tohtml)
      return lines unless i7tohtml
      stdout, stderr, rc = Open3.capture3(i7tohtml, @filename)
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
    
    def initialize(filename)
      @pathname = Pathname.new(filename)
      @filename = @pathname.expand_path.to_s
      return true
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
