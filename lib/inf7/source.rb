require 'open3'
require 'pp'
require 'tty-table'
require 'tty-screen'
require 'tabulo'
module Inf7
  class Source
    extend Inf7
    def self.pretty_print(filename, options)
      source = filename.end_with?('.i7x') ? Inf7::Extension.new(filename) : Inf7::Source.new(filename)
      if options[:html] # and Inf7::Conf.conf[:i7tohtml] and check_executable(Inf7::Conf.conf[:i7tohtml])
        puts source.pp_html
      else
        source.text_prettyprint(options)
      end
    end

    def pp_html
      Inf7::Template[:inform7_source].render(code: pretty_print)
    end
    
    def content
      @content ||= File.read(@filename)
    end

    def lines
      content.split($/)
    end

    # def table_render(table, width)

    #   multi_renderer = TTY::Table::Renderer::Basic.new(table, multiline: true, width: TTY::Screen.cols)
    #   puts multi_renderer.render
    #   return
      

      
    #   basic_rendering = table.render(:basic, resize: true)
    #   basic_width = basic_rendering.split($/).map(&:length).max
    #   puts basic_width
    #   if basic_width > width and basic_width <= TTY::Screen.cols
    #     pp basic_rendering
    #     puts basic_rendering
    #   else
    #     puts table.render(:basic, resize: true, width: TTY::Screen.cols)
    #   end
    # end
    
    def text_prettyprint(options = {})
      table_rows = nil
      max_width = 0
      screen_width = options[:width] || [ 100, TTY::Screen.cols ].min
      preprocess.each do |l|
        if l.match(/\t/)
          table_rows ||= []
          row = l.split(/\t/)
          max_width = row.count if row.count > max_width
          table_rows << row
          next
        elsif table_rows
          table_rows = table_rows.map {|r| r+=[""]*(max_width-r.count)}# .render(:basic, resize: true, multiline: true,  width: TTY::Screen.cols)
          table = TTY::Table.new(rows: table_rows)
          rendered = table.render(:unicode, width: 999999)
          table_width = rendered.split($/).first.length
#           puts table_width
#           puts rendered
#           pp table_rows
#           puts max_width


          
# columns = (0..max_width-1).to_a.map { |i| table_rows.map{|r| r[i]  } }


          

          
#           col_widths = table_rows.map {|r| r.map {|c| [ c.length, c.split(/\s+/).map(&:length).max ] } }
#           pp col_widths
          
          # recursive algorithm: find widest column. Either cut it in half or set to width of its longest word, whichever is longer. if table still too wide, repeat.
          # when all columns have no lines with spaces that are longer than that column's longest word we've gone as far as we can.
          

          
#          puts table_render(TTY::Table.new(rows: table_rows.map {|r| r+=[""]*(max_width-r.count)}),screen_width)
          table_rows = nil
          max_width = 0
        end
        if !table_rows and (l.length > screen_width)
          l.match(/\A(\s*)(.*)\Z/)
          initial_whitespace, rest = $1, $2
          print initial_whitespace
          used = initial_whitespace.length
          words = rest.split(/\s+/)
          while !words.empty?
            if used+words[0].length > screen_width
              puts
              used = 0
            end
            used += words[0].length + 1

            print "#{words.shift} "
            
          end
          puts
        else
          puts l
        end
      end
    end

    
    def preprocess(string = content)
      prepped = []
      string.split($/).each do |line|
        if line.match(/\A(\s+)(.*)\Z/)
          whitespace, remainder = $1, $2
          line = whitespace.gsub(/\t/, '   ') + remainder.rstrip
        end
        prepped << line.gsub(/\t+/,"\t")
      end
      prepped
    end
    
    def pretty_print(i7tohtml = nil, source_lines: lines)
      i7tohtml ||= Inf7::Source.check_executable(Inf7::Conf.conf[:i7tohtml])
      return source_lines unless i7tohtml
      stdout, stderr, rc = Open3.capture3(i7tohtml, :stdin_data => source_lines.join($/))
      return stdout.split($/) if rc.exitstatus and rc.exitstatus.zero? # on SIGSEGV exitstatus is nil
      STDERR.puts "Failed"
      STDERR.puts(stdout) if stdout
      STDERR.puts(stderr) if stderr
      raise RuntimeError.new("error running #{i7tohtml}")
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
