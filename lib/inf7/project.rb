require_relative './conf'
require_relative 'template'

require 'securerandom'
require 'fileutils'
require 'tty-which'
require 'nokogiri'
require 'pathname'
require 'optimist'
require 'tmpdir'
require 'open3'
require 'erubi'
require 'find'
require 'yaml'
require 'set'

module Inf7

  class Project
    GamefileBasename = 'output'
    Defaults = { author: "",
                 i6flagstest: '-wE2SD',
                 i6flagsrelease: '-wE2~S~D',
                 i7flagstest: '',
                 i7flagsrelease: '',
                 cblorbflags: '-unix',
                 create_blorb: true,
                 nobble_rng: false,
                 blorbfile_basename: 'output',
                 top: false,
                 git: false,
                 :format => "glulx",
                 index: true,
                 force: false,
                 progress: false,
               }
    Fields = (Defaults.keys + Inf7::Executables.keys + [:internal, :external, :release, :resources, :docs, :quiet ]).to_set
    CompileFields = Fields - [ :i6flagstest, :i6flagsrelease, :i7flagstest, :i7flagsrelease ] + [ :i6flags, :i7flags, :index, :force, :verbose ]
    
    SettingsFields = %i{ create_blorb nobble_rng format }.to_set
    
    attr_reader :dir, :name, :settings_file, :story, :source, :extensions_dir, :build, :release, :inf, :uuid, :story_html, :quiet
    attr_accessor :conf #:format, :create_blorb, :nobble_rng
    def self.bare_compile(filename, **args)
      Optimist::die "Can't find #{filename}" unless File.exist?(filename)
      cwd = Dir.pwd
      Dir.mktmpdir do |tmpdir|
        project = Inf7::Project.new(tmpdir, { top: true, allow_prior_existence: true })
        FileUtils.cp filename, project.story
        args[:create_blorb] = false
        args[:index] = false
        success = project.compile(args)
        if success
          FileUtils.cp project.output, File.join(cwd, "#{File.basename(filename, '.ni')}.#{project.suffix}")
        end
      end
    end

    def self.smoketest(options)
      Optimist::die "Can't find #{options[:ext]}" unless File.exist?(options[:ext])
      Dir.mktmpdir do |tmpdir|
#        project = Inf7::Project.new(tmpdir, {}.merge(Inf7::Project::Defaults).merge(Inf7::Conf.conf).merge(options).merge( { top: true, allow_prior_existence: true }))
        project = Inf7::Project.new(tmpdir, {}.merge(options).merge( { top: true, allow_prior_existence: true }))
        ext_name, ext_author = Inf7::Project.install({ext: options[:ext], project: project}, [])
        Inf7::Template.write(:smoketest, project.story, ext: ext_name, author: ext_author)
        project.compile({index: false})
      end
    end
    
    def self.find_dir(args=[])
      if !args.empty?
        dir = Pathname.new(args.shift).realdirpath
        name = File.basename(dir)
        return File.read(dir.join('.i7_alias')), dir if File.exist?(dir.join('.i7_alias'))
        return dir if dir.to_s.end_with?('.inform') and Dir.exist?(dir)
        return dir.join("#{name}.inform") if Dir.exist?(dir.join("#{name}.inform"))
        return Pathname.new("#{dir}.inform") if Dir.exist?("#{dir}.inform")
        Optimist.die("Can't find project for #{dir}")
      else
        dir = Pathname.new(Dir.pwd)
        return File.read(dir.join('.i7_alias')), dir if File.exist?(dir.join('.i7_alias'))
        return dir.join("#{File.basename(dir)}.inform") if Dir.exist?(dir.join("#{File.basename(dir)}.inform")) # top was specified; one case of looking down instead of up
        while !dir.to_s.match(/\.(?:inform|materials)$/)
          dir = Pathname.new(dir).parent
          Optimist.die("Couldn't find a project") if dir.root?
        end
        dir = Pathname.new(dir)
        dir = dir.parent.join("#{$1}.inform") if dir.basename.to_s.match(/(.*)\.materials$/)
        dir.to_s
      end
    end
    
    def self.[](args, conf={})
      dir, fake = find_dir(args)
      if fake
        conf[:fakedir] = Pathname.new(fake).expand_path
        conf[:fake] = File.basename(fake)
      end
      Inf7::Doc.load
      self.new(dir.to_s, conf, false)
    end

    def self.install(options, args)
      ext = Pathname.new(options[:ext]).expand_path
      Optimist.die("#{ext} does not exist") unless File.exist?(ext)
      author_dir, extension_filename = ext.split[-2,2]
      author_dir = author_dir.basename
      if options[:init]
        dest_dir = File.join(Inf7::Conf.dir, 'extensions')
      else
        dest_dir = (options[:project] ? options[:project] : Inf7::Project[args]).extensions_dir
      end
      destination = File.join(dest_dir, author_dir, extension_filename)
      Optimist.die("#{destination} already exists") if File.exist?(destination)
      FileUtils.mkdir_p(File.join(dest_dir, author_dir))
      FileUtils.cp(ext, destination)
      return File.basename(extension_filename, '.i7x'), author_dir
    end
    
    def set(conf)
      @conf = @conf.merge(conf)
      write_settings_file
      write_rc
    end      

    def create_extension
      ext_author = opt(:author)
      Optimist.die("Non-empty author required") if ext_author.empty?
      ext_name = opt(:name).sub(/\.i7x\Z/,'')
      Optimist.die("name required") if ext_name.empty?
      filename = "#{File.join(@extensions_dir, ext_author, ext_name)}.i7x"
      Inf7::Template.write(:extension, filename, name: opt(:name), author: ext_author)
      report "Created #{filename}. You must manually include it."
    end

    def initialize(name, conf=nil, new=true)
      Optimist.die("Must run setup first") unless Inf7::Conf.conf
      if (conf[:quiet] and conf[:verbose])
        %i{ quiet verbose }.each {|s| conf.delete(s)}
      end
      @quiet = conf[:quiet]
      @verbose = conf[:verbose]
      conf.delete(:quiet) if @quiet
      # can't use opt yet
      if new and (conf[:git] || conf[:top] || Inf7::Conf.conf[:top] || Inf7::Conf.conf[:git])
        if name.match(/(.*)\.inform\Z/)
          @name = File.basename($1)
        else
          @name = File.basename(name)
        end
        @top = Pathname.new(File.join(File.dirname(name), @name))
        Optimist.die("#{@top} already exists") if File.exist?(@top) unless conf[:allow_prior_existence]
        dir = @top.join("#{@name}.inform")
      else 
        if name.match(/(.*)\.inform$/)
          dir = name
          @name = File.basename($1)
        else
          @name = File.basename(name)
          dir="#{name}.inform"
        end
      end
      @dir = Pathname.new(dir).expand_path
      @top ||= Pathname.new(@dir.parent.expand_path)
      @source = @dir.join('Source') # File.join(@dir, 'Source')
      @story = @source.join('story.ni') # File.join(@source, 'story.ni')
      if new
        Optimist.die("#{@dir} already exists") if Dir.exist?(@dir)
        FileUtils.mkdir_p(@dir)
      else
        Optimist.die("#{@source} not found") unless Dir.exist?(@source)
        Optimist.die("#{@story} not found") unless File.exist?(@story)
      end
      @materials = @top.join("#{@name}.materials")
      @build = @dir.join('Build') # File.join(@dir, 'Build')
      @inf = @build.join('auto.inf') #File.join(@build, 'auto.inf')
      @release = @materials.join('Release')
      @extensions_dir = @materials.join('Extensions')
      @settings_file = @dir.join('Settings.plist')
      @rc = @dir.join('.rc.yml') # File.join(dir, '.rc.yml')
      @uuid = @dir.join('uuid.txt') # File.join(@dir, 'uuid.txt')
      @index_root = @dir.join('.index').to_s

      write_uuid unless File.exist?(@uuid)
      if new
        Optimist.die("#{@materials} already exists") if Dir.exist?(@materials)
        [ @source, @build, @extensions_dir, @release ].each {|d| FileUtils.mkdir_p(d) }
        @conf = conf
        create_story
        ext_dir = File.join(Inf7::Conf.dir, 'extensions')
        if Dir.exist?(ext_dir)
          Dir.entries(ext_dir).reject {|x| x.start_with?('.')}.each {|author_dir| FileUtils.cp_r(File.join(ext_dir,author_dir), @extensions_dir)  }
        end
        if opt(:git)
          Dir.chdir(@top.to_s) do
            system 'git', 'init'
            Inf7::Template.write(:gitignore, '.gitignore')
          end
        end
        write_uuid
        write_settings_file
        write_rc
        puts "Created #{@dir}" unless quiet
      else
        File.open(@rc,'w') {|f| f.write(YAML.dump({ create_blorb: opt(:create_blorb), nobble_rng: opt(:nobble_rng), :format => opt(:format)}))} if !File.exist?(@rc)
        @conf = YAML.load(File.read(@rc))
        write_settings_file if !File.exist?(@settings_file)
        @conf[:nobble_rng] = ('true' == settings.at_xpath("//*[preceding-sibling::key[contains(text(),'IFSettingNobbleRng')]]").name)
        @conf[:create_blorb] = ('true' == settings.at_xpath("//*[preceding-sibling::key[contains(text(),'IFSettingCreateBlorb')]]").name)
        @conf[:format] = Inf7::Zcode_to_format[settings.at_xpath("//integer[preceding-sibling::key[contains(text(),'IFSettingZCodeVersion')]]").inner_text]
        @conf = @conf.merge(conf) if conf
      end
    end

    def write_uuid
      File.open(@uuid,'w') {|f| f.write(SecureRandom.uuid) }
    end
    
    def write_settings_file(defaults = nil)
      Inf7::Template.write(:settings, @settings_file, project: self)
    end
    
    def write_rc
      File.open(@rc,'w') {|f| f.write(YAML.dump(rc_conf)) }
    end

    def zcode_version
      Inf7::FormatStuff[opt(:format)][:zcode_version]
    end
    
    def settings_conf
      @conf.select {|k,v| Inf7::Project::SettingsFields.member?(k) }
    end

    def rc_conf
      @conf.reject {|k,v| (%i{ top git fake fakedir }.to_set + Inf7::Project::SettingsFields).member?(k) }
    end

    def opt(key)
      key = key.to_sym
      return @conf[key] if @conf.key?(key)
      return Inf7::Conf.conf[key] if Inf7::Conf.conf.key?(key)
      return Inf7::Project::Defaults[key] if Inf7::Project::Defaults.key?(key)
      return nil
    end

    def settings
      @settings = Nokogiri::XML(File.read(@settings_file))
    end

    def suffix
      FormatStuff[opt(:format)][:suffix]
    end
    
    def create_story
      Inf7::Template.write(:story, @story, project: self) unless File.exist?(@story)
    end

    def i6flag
      Inf7::FormatStuff[opt(:format)][:i6flag]
    end
    
    def output
      File.join(@build, "#{Inf7::Project::GamefileBasename}.#{Inf7::FormatStuff[opt(:format)][:suffix]}")
    end

    def release_blurb
      File.join(@dir, 'Release.blurb')
    end

    def blorb_suffix
      Inf7::FormatStuff[opt(:format)][:blorb]
    end

    def blorb
      File.join(@build, "#{opt(:blorbfile_basename)}.#{blorb_suffix}")
    end

    def print_settings(options)
      rc = YAML.load(File.read(@rc))
      conf = Inf7::Conf.conf

      if (options[:project] || options[:all] || !(options[:all] || options[:user] || options[:defaults]))
        puts "\n#{name} project settings"
        puts "  create_blorb: #{opt(:create_blorb) ? 'true' : 'false'}"
        puts "  format: #{opt(:format)}"
        puts "  nobble_rng: #{opt(:nobble_rng) ? 'true' : 'false'}"
        rc.keys.sort.each {|k| puts "  #{k}: #{rc[k]}"}
      end
      if (options[:user] || options[:all])
        puts "\nUser-wide settings"
        conf.keys.reject {|k| rc.key?(k) || Inf7::Project::SettingsFields.member?(k)}.each {|k| puts "  #{k}: #{conf[k]}"}
      end
      if (options[:defaults] || options[:all])
        puts "\nDefaults"
        Inf7::Project::Defaults.keys.reject {|k| rc.key?(k) || Inf7::Project::SettingsFields.member?(k) || conf.key?(k)}.each {|k| puts "  #{k}: #{Inf7::Project::Defaults[k]}"}
      end
    end

    def deform(string)
      case string
      when /index\.html/
        "file://#{Inf7::Conf.doc}/index.html"
      when /Extensions\/(Extensions|ExtIndex)\.html/
        "file://#{@index_root}/doc/#{$1}.html"
      when /^\/Extensions/
        target = string.sub(/\A\/Extensions\/Extensions/,'/Extensions')
        "file://#{@index_root}/doc#{target}"
      when /(R?doc\d+\.html)/
        "file://#{Inf7::Conf.doc}/#{Inf7::Doc.links.key?($1) ? [Inf7::Doc.links[$1][:file],Inf7::Doc.links[$1][:anchor]].join('#') : 'xyzzyplugh'}"
      else
        "file://#{Inf7::Conf.doc}/#{string}"
      end
    end

    def transform_html(infile, outfile)
      return if up_to_date(infile, outfile)
      FileUtils.mkdir_p(File.dirname(outfile))
      contents = File.read(infile)
      contents.gsub!(%r{"inform:/([^"]+)"}) {|match| %Q{"#{deform($1)}"} }
      contents.gsub!(%r{'inform:/([^']+)'}) {|match| %Q{'#{deform($1)}'} }
      contents.gsub!(%r{inform:/([^\s>]+)}) {|match| deform($1) }
      contents.gsub!(/source:story\.ni/, "file://#{@story_html}")
      contents.gsub!(/function pasteCode/,"#{Inf7::Template[:copycode].render} function pasteCode");
      contents.gsub!(/"javascript:pasteCode\('([^']+)'\)"/) do |m|
        %Q{"javascript:copyCode(`#{Inf7::Doc.fix_javascript($1)}`)"}
      end
      node = Nokogiri::HTML(contents)
      navbar_div = Inf7::Doc::Doc.create_element('div')
      navbar_div.inner_html = Inf7::Template[:index_navbar].render(index_root: @index_root, build: @build.to_s)
      node.at_css('body').first_element_child.before(navbar_div)
      File.open(outfile, 'w') {|f| f.write(Inf7::Doc.to_html(node, :chapter, :html)) }
    end

    def make_story_html
      @story_html ||= File.join(@index_root, 'story.html')
      unless up_to_date(@story, @story_html)
        Inf7::Template.write(:story_html, @story_html, story: File.read(@story), name: @name, index_root: @index_root, build: @build)
      end
    end
    
    def reindex
      make_story_html
      Inf7::Doc.write_template_files
      prefix_regexp = %r{^#{File.join(opt(:external),'Documentation')}/}
      ext_doc_dir = File.join(@index_root, 'doc')
      FileUtils.mkdir_p(ext_doc_dir)
      Find.find(File.join(opt(:external),'Documentation')) do |path|
        next unless path.end_with?('.html')
        the_end = path.sub(prefix_regexp, '')
        outfile = File.join(ext_doc_dir, the_end)
        transform_html(path, outfile)
      end
      Find.find(@dir.join('Index')) do |path|
        next unless path.match(/(Index\/.*\.html)\Z/)
        transform_html(path, File.join(@index_root,$1))
      end
      index_html = @dir.join('index.html')
      FileUtils.ln_s(File.join(@index_root,'Index','Welcome.html'), index_html) unless File.exist?(index_html)
    end

    def compile(options={})
      compile_ni(options) && compile_inform6(options) && compile_cblorb(options)
    end

    def fake
      @conf[:fake] = opt(:name) || cli_ize(@name)
      @conf[:fakedir] = Pathname.new(@conf[:fake]).expand_path
      Optimist::die "#{@conf[:fakedir]} already exists" if File.exist?(@conf[:fakedir])
      FileUtils.mkdir_p(@conf[:fakedir])
      make_fakes
      File.open(@conf[:fakedir].join('.i7_alias'), 'w') {|f| f.write(@dir)}
      report "Created #{@conf[:fake]} as fake version of #{@name}"
    end
    
    private

    def report(str="")
      puts str unless @quiet
    end
    
    def make_fakes
      if @conf[:fake] and @conf[:fakedir] and File.exist?(@conf[:fakedir])
        { @story => @conf[:fakedir].join("#{@conf[:fake]}.ni"),
          @extensions_dir => @conf[:fakedir].join("extensions"),
          @release => @conf[:fakedir].join("release"),
          @uuid => @conf[:fakedir].join(".uuid"),
          @settings_file => @conf[:fakedir].join(".settings.plist"),
          release_blurb => @conf[:fakedir].join(".release.blurb"),
          @inf => @conf[:fakedir].join("#{@conf[:fake]}.inf"),
          @dir.join('.index','Index','Welcome.html') => @conf[:fakedir].join('index.html'),
          output => @conf[:fakedir].join("#{@conf[:fake]}.#{suffix}"),
          @build.join('problems.html') => @conf[:fakedir].join('problems.html'),
          @build.join('Debug log.txt') => @conf[:fakedir].join('debug_log.txt'),
          blorb => @conf[:fakedir].join("#{@conf[:fake]}.#{blorb_suffix}"),
        }.each_pair do |file, symlink|
          FileUtils.ln_s(file, symlink) if file and !file.empty? and File.exist?(file) and !File.exist?(symlink)
        end
      end
    end
          
    def check_executable(name)
      location = opt(name) || TTY::Which.which(Inf7::Executables[name])
      Optimist.die "Can't find #{name}: it must be specified, in settings, or in PATH" unless location
      location
    end

    def compile_ni(options)
      ni = check_executable(:ni)
      if (File.exist?(@inf) and File.size(@inf).zero?) or !up_to_date(@source, @inf) or Dir[File.join(@extensions_dir, '*', '*.i7x')].any? {|ext| !up_to_date(ext, @source) }
        arg_list = []
        i7flags = options.key?(:i7flags)  ? options[:i7flags] : (options[:release] ? opt(:i7flagsrelease) : opt(:i7flagstest))
        arg_list << i7flags if !i7flags.empty?
        { nobble_rng: :rng, release: release }.each_pair {|k,v| arg_list << "--#{v}" if opt(k) }
        %i{ index progress }.each {|s| arg_list << "--no#{s}" if !opt(s) }
        arg_list += [ '--internal', opt(:internal), '--external', opt(:external), '--project', dir.to_s ]
        report ([ni]+arg_list).join(' ')
        FileUtils.mkdir_p(opt(:external))
        stdout, stderr, rc = Open3.capture3(ni, *arg_list)
        out_lines = stdout.split($/)
        out_lines[1].match(/source text, which is (\d+) words long\./)
        word_count = $1
        out_lines[-2].match(/(There were.*things\.)/)
        room_thing_count = $1
        %w{ Problems StatusCblorb }.each do |basename|
          filename = @build.join("#{basename}.html").to_s
          transform_html(filename, @build.join("#{basename.downcase}.html")) if File.exist?(filename)
        end
        if rc.exitstatus.zero?
          report opt(:verbose) ? stdout : "Compiled #{word_count}-word source. #{room_thing_count}"
          reindex if opt(:index)
        else
          STDERR.puts "Attempted to compile #{word_count}-word source."
          STDERR.write(stderr)
          return false
        end
        make_fakes if @conf[:fake]
        return true
      else
        report "#{@inf} up to date"
        return true
      end
    end

    def compile_inform6(options)
      report # output newline
      i6flags_arg = options[:i6flags] ? options[:i6flags] : (options[:release] ? opt(:i6flagsrelease) : opt(:i6flagstest))
      if up_to_date(inf, output)
        report "#{output} up to date"
        return true
      else
        inform6 = check_executable(:inform6)
        report "#{inform6} #{i6flags_arg}#{i6flag} #{inf} #{output}"
        stdout, stderr, rc = Open3.capture3(inform6, "#{i6flags_arg}#{i6flag}", inf.to_s, output.to_s)
        if rc.exitstatus.zero?
          report opt(:verbose) ? stdout : stdout.split($/).select {|l| l.match(/\A(Inform|In:|Out:)/) }.join("\n")
        else
          STDERR.write(stdout)
          STDERR.write(stderr)
          return false
        end
        make_fakes if @conf[:fake]
        return true
      end
    end

    def compile_cblorb(options)
      return true unless opt(:create_blorb)
      report # output newline
      cblorb = check_executable(:cblorb)
      # TODO to check blorb mtime we need to check everything in Release
      if up_to_date(output, blorb)
        report "#{blorb} up to date"
      else
        report "#{cblorb} #{opt(:cblorbflags)} #{release_blurb} #{blorb}"
        stdout, stderr, rc = Open3.capture3(cblorb, opt(:cblorbflags), release_blurb.to_s, blorb.to_s)
        if rc.exitstatus.zero?
          report opt(:verbose) ? stdout : stdout.split($/).map {|l| l.match(/\A!\s+((cBlorb|Completed).*)/); $1}.compact.join("\n")
        else
          STDERR.write(stderr)
          return false
        end
        make_fakes if @conf[:fake]
        return true
      end
    end

    def up_to_date(file1, file2)
      !opt(:force) and File.exist?(file2) and (File.mtime(file2) > File.mtime(file1))
    end
    
    def cli_ize(str)
      str.downcase.gsub(/[^-\w]/,'_').gsub(/_+/,'_')
    end

  end
end
