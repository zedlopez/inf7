require_relative './conf'
require_relative 'template'

require 'securerandom'
require 'fileutils'
require 'net/http'
require 'nokogiri'
require 'pathname'
require 'optimist'
require 'tempfile'
require 'tmpdir'
require 'open3'
require 'erubi'
require 'find'
require 'yaml'
require 'set'

module Inf7

  class Project
    extend Inf7
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
                 arch: 'x86_64'
               }
    Fields = (Defaults.keys + [:ni, :inform6, :cblorb, :i7tohtml, :internal, :external, :release, :resources, :docs, :quiet, :download, :zterp, :gterp, :cheap_glulx, :cheap_zcode, :browser ]).to_set
    CompileFields = Fields - [ :i6flagstest, :i6flagsrelease, :i7flagstest, :i7flagsrelease ] + [ :i6flags, :i7flags, :index, :force, :verbose ]
    
    SettingsFields = %i{ create_blorb nobble_rng format }.to_set
    
    attr_reader :dir, :name, :settings_file, :story, :source, :extensions_dir, :build, :inf, :uuid, :quiet
    attr_accessor :conf #:format, :create_blorb, :nobble_rng



    
    def self.print_settings(options, rc = {})
      options[:all] = !(options[:user] || options[:defaults])
      conf = Inf7::Conf.conf
      if (options[:user] || options[:all])
        puts "\nUser-wide settings"
        conf.keys.reject {|k| rc.key?(k) || Inf7::Project::SettingsFields.member?(k)}.each {|k| puts "  #{k}: #{conf[k]}"}
      end
      if (options[:defaults] || options[:all])
        puts "\nDefaults"
        Inf7::Project::Defaults.keys.reject {|k| rc.key?(k) || Inf7::Project::SettingsFields.member?(k) || conf.key?(k)}.each {|k| puts "  #{k}: #{Inf7::Project::Defaults[k]}"}
      end
    end

    def self.set(options)
      filename = File.join(Inf7::Conf.dir, 'inf7.yml')
      Optimist::die("User settings don't exist; run setup") unless File.exist?(filename)
      conf = YAML.load(File.read(filename)).merge(options.reject {|k| !Inf7::Project::Fields.member?(k)})
      File.open(filename, 'w') {|f| f.write(YAML.dump(conf)) }
    end
    
    def self.bare_compile(filename, **args)
      Optimist::die "Can't find #{filename}" unless File.exist?(filename)
      cwd = Dir.pwd
      Dir.mktmpdir do |tmpdir|
        project = Inf7::Project.new(tmpdir, { top: true, allow_prior_existence: true })
        FileUtils.cp filename, project.story
        args[:create_blorb] = false
        args[:index] = false
        success = project.compile(args.merge({temp: true}))
        if success
          FileUtils.cp project.output, File.join(cwd, "#{File.basename(filename, '.ni')}.#{project.suffix}")
        end
      end
    end

    def self.census(options)
      Dir.mktmpdir do |tmpdir|
        project = Inf7::Project.new(tmpdir, options.merge( { top: true, allow_prior_existence: true }))
        project.census(force: options[:force])
      end
    end

    def self.write_partial(source_file, output_file, force: false, project: nil, **h)
      #      source_file = source_file.to_s
      extension = Inf7::Extension.new(source_file)
      # TODO generic up_to_date ?
      return File.read(output_file) if !force and File.exist?(output_file) and File.mtime(output_file) >= File.mtime(source_file)
      FileUtils.mkdir_p(File.dirname(output_file))
      i7tohtml = (project || self).check_executable(:i7tohtml)
      doc, code, example_pasties = extension.get_doc_and_code(i7tohtml)
      Inf7::Template.write(:source_code_partial, output_file, documentation: doc, code: code, example_pasties: example_pasties, **h)
    end
    
    def self.update_extension_docs(internal:, external:, project: nil, force: false)
      puts "Project.update_extension_docs #{force}"
      extension_locations = Hash.new {|h,k| h[k] = {} }
      extension_dir_list = [ external, File.join(internal, 'Extensions') ]
      extension_dir_list.unshift(project.extensions_dir) if project
      extension_dir_list.each do |ext_dir|
        Dir[File.join(ext_dir, '*', '*.i7x')].each do |extension|
          ext_obj = Inf7::Extension.new(extension)
           extension_locations[ext_obj.author_dir.downcase][ext_obj.ext_name.downcase] ||= { author: ext_obj.author_dir, ext_name: ext_obj.ext_name, path: extension }
        end
      end

      extension_locations.keys.each do |author_dir|
        extension_locations[author_dir].each_pair do |ext_base, hash|
          next unless hash
          dest_dir = File.join(Inf7::Conf.ext, File.dirname(hash[:path]))
          contents_dest_file = File.join(dest_dir, "#{ext_base}.html")
          name = "#{hash[:ext_name]} by #{hash[:author]}"
          puts "writing partial for #{name} -> #{contents_dest_file}"
          content = write_partial(hash[:path], contents_dest_file, force: force, name: name, project: project)
          project.update_extension_doc(author_dir, ext_base, name, content, contents_dest_file, force: force) if project
        end
      end
    end

    def self.smoketest(options)
      Optimist::die "Can't find #{options[:ext]}" unless File.exist?(options[:ext])
      Dir.mktmpdir do |tmpdir|
        project = Inf7::Project.new(tmpdir, {}.merge(options).merge( { top: true, allow_prior_existence: true, index: false }))
        ext_obj = Inf7::Project.install({ext: options[:ext], project: project}, [])
        Inf7::Template.write(:smoketest, project.story, ext: ext_obj.ext_name, author: ext_obj.author_dir)
        project.compile({ temp: true })
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
#      ext = Pathname.new(options[:ext]).expand_path
      Optimist.die("#{ext} does not exist") unless File.exist?(ext)
#      author_dir, ext_base = Inf7::Extension.author_extbase(ext)
#      author_dir, extension_filename = ext.split[-2,2]
      #      author_dir = author_dir.basename
      ext_obj = Inf7::Extension.new(ext)
      if options[:init]
        dest_dir = File.join(Inf7::Conf.dir, 'extensions')
      else
        dest_dir = (options[:project] ? options[:project] : Inf7::Project[args]).extensions_dir
      end
      destination = File.join(dest_dir, ext_obj.i7x(:author))
      Optimist.die("#{destination} already exists") if File.exist?(destination)
      FileUtils.mkdir_p(File.join(dest_dir, ext_obj.author_dir))
      FileUtils.cp(ext_obj.filename, destination)
      return ext_obj
    end

    def census(force: false)
      ni = check_executable(:ni)
      if ni
        args = [ '--noprogress', '--internal', opt(:internal), '--external', opt(:external), '--census' ]
        report ([ni]+args).join(' ')
        stdout, stderr, rc = Open3.capture3(ni, *args)
        if rc.exitstatus.zero?
          report stdout unless opt(:quiet)
          Inf7::Project.update_extension_docs(internal: opt(:internal), external: opt(:external), force: force, project: self)
        else
          STDERR.puts(stderr)
        end
      end
    end
    
    def set(conf)
      @conf = @conf.merge(Inf7::Conf.absolutify(conf))
      write_settings_file
      write_rc
    end      

    def update_project_extension_docs(force: false)
      puts "update_project_extension_docs #{force}"
      Inf7::Project.update_extension_docs(internal: opt(:internal), external: opt(:external), project: self, force: force)
      ext_doc_dir = File.join(@index_root, 'doc')
      FileUtils.mkdir_p(ext_doc_dir)
      transform_html(File.join(opt(:external), 'Documentation', 'Extensions.html'), File.join(ext_doc_dir, 'Extensions.html')) 
    end

    def update_extension_doc(author_dir, ext_base, name, content, contents_dest_file, force: false)
      dest_dir = File.join(@index_root, 'source', author_dir)
      FileUtils.mkdir_p(dest_dir)
      dest_file = File.join(dest_dir, "#{ext_base}.html")
      Inf7::Template.write(:inform7_source, dest_file, contents: content, index_root: @index_root, build: @build, name: name) unless up_to_date(contents_dest_file, dest_file)
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
          Dir[File.join(ext_dir, '*', '*.i7x')].each do |extension|
            author_dir, ext_name = Inf7::Extension.author_extbase(extension)
            dest_dir = File.join(@extensions_dir, author_dir)
            FileUtils.mkdir_p(dest_dir)
            FileUtils.cp(extension, dest_dir)
          end
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
        write_initial_index
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
      index_html = @dir.join('index.html')
      FileUtils.ln_s(File.join(@index_root,'Index','Welcome.html'), index_html) unless File.symlink?(index_html)
    end

    def write_initial_index
      [ { file: File.join(@index_root, 'Index', 'Welcome.html'), head: 'Empty Index', text: 'Either this is a new project or the last compile was unsuccessful.' },
        { file: File.join(@build, 'problems.html'), head: 'No problem!', text: 'No compile has been attempted.' }, ].each do |h|
        Inf7::Template.write(:generic_page, h[:file], **h)
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

      if (options[:all] || !(options[:user] || options[:defaults]))
        puts "\n#{name} project settings"
        puts "  create_blorb: #{opt(:create_blorb) ? 'true' : 'false'}"
        puts "  format: #{opt(:format)}"
        puts "  nobble_rng: #{opt(:nobble_rng) ? 'true' : 'false'}"
        rc.keys.sort.each {|k| puts "  #{k}: #{rc[k]}"}
      end
      Inf7::Project.print_settings(options, rc)
    end

    def deform(string)
      case string
      when /index\.html/
        "file://#{Inf7::Conf.doc}/index.html"
      when /Extensions\/(Extensions|ExtIndex)\.html/
        "file://#{@index_root}/doc/#{$1}.html"
      when /^\/Extensions/
        target = string.sub(/\A\/Extensions\/Extensions/,'')
        "file://#{@index_root}/source#{target.downcase}"
      when /(R?doc\d+\.html)/
        "file://#{Inf7::Conf.doc}/#{Inf7::Doc.links.key?($1) ? [Inf7::Doc.links[$1][:file],Inf7::Doc.links[$1][:anchor]].join('#') : 'xyzzyplugh'}"
      else
        "file://#{Inf7::Conf.doc}/#{string}"
      end
    end

    def transform_html(infile, outfile, override: false)

      return if up_to_date(infile, outfile) unless override
      @copycode ||= Inf7::Template[:copycode].render
      @navbar ||= Inf7::Template[:index_navbar].render(index_root: @index_root, build: @build.to_s)
      FileUtils.mkdir_p(File.dirname(outfile))
      contents = File.read(infile)
      contents.gsub!(%r{"inform:/([^"]+)"}) {|match| %Q{"#{deform($1)}"} }
      contents.gsub!(%r{'inform:/([^']+)'}) {|match| %Q{'#{deform($1)}'} }
      contents.gsub!(%r{inform:/([^\s>]+)}) {|match| deform($1) }
      contents.gsub!(/source:story\.ni/, "file://#{File.join(@index_root, 'story.html')}")
      contents.gsub!(/function pasteCode/,"#{@copycode} function pasteCode");
      contents.gsub!(/"javascript:pasteCode\('([^']+)'\)"/) do |m|
        %Q{"javascript:copyCode(`#{Inf7::Doc.fix_javascript($1)}`)"}
      end
      contents.gsub!(%r{"source:.*?Extensions/([^#]+)(#line\d+)"}) do |m|
        ext_name = File.basename($1, '.i7x')
        author = File.dirname($1)
        %Q{"file://#{File.join(@index_root, 'source', author, ext_name + '.html' + $2)}"}
      end
      node = Nokogiri::HTML(contents)
      navbar_div = Inf7::Doc::Doc.create_element('div')
      navbar_div.inner_html = @navbar
      node.at_css('body').first_element_child.before(navbar_div)
      File.open(outfile, 'w') {|f| f.write(Inf7::Doc.to_html(node, :chapter, :html)) }
    end

    def write_source(source_file, output_file, **h) # only used for story
      # doesn't check up_to_date
      source = Inf7::Source.new(source_file)
#      source_file = source_file.to_s
#      source_obj = source_file.end_with?('.i7x') ? Inf7::Extension.new(source_file) : Inf7::Source.new(source_file)
      
      #doc, code = source_obj.get_doc_and_code(check_executable(:i7tohtml))
      contents = Inf7::Template[:source_code_partial].render(documentation: nil, code: source.pretty_print(check_executable(:i7tohtml)))
      Inf7::Template.write(:inform7_source, output_file, contents: contents, **h)
    end

    def make_source_html
#      extension_locations = Hash.new {|h,k| h[k] = {} }
#      extension_dir_list = [ opt(:external), File.join(opt(:internal), 'Extensions') ]
      Inf7::Doc.write_template_files
#      unless nothing_personal 
      story_html = File.join(@index_root, 'story.html')
      write_source(@story, story_html, index_root: @index_root, build: @build, name: @name)
 #       extension_dir_list.unshift(@extensions_dir)
        
 #     end
      # extension_dir_list.each do |ext_dir|
      #   Dir[File.join(ext_dir, '*', '*.i7x')].each do |extension|
      #     author_dir, ext_name = *author_extbase(extension)
      #      extension_locations[author_dir.downcase][ext_name.downcase] ||= { author: author_dir, ext_name: ext_name, path: extension }
      #   end
      # end

      # extension_locations.keys.each do |author_dir|
      #   extension_locations[author_dir].each_pair do |ext_base, hash|
      #     next unless hash
      #     dest_dir = File.join(Inf7::Conf.ext, File.dirname(hash[:path]))
      #     contents_dest_file = File.join(dest_dir, "#{ext_base}.html")
      #     name = "#{hash[:ext_name]} by #{hash[:author]}"
      #     write_partial(hash[:path], contents_dest_file, name: name)
      #     unless nothing_personal
      #       dest_dir = File.join(@index_root, 'source', author_dir)
      #       FileUtils.mkdir_p(dest_dir)
      #       dest_file = File.join(dest_dir, "#{ext_base}.html")
      #       Inf7::Template.write(:inform7_source, dest_file, contents: File.read(contents_dest_file), index_root: @index_root, build: @build, name: name) unless up_to_date(contents_dest_file, dest_file)
      #     end
      #   end
      # end
      # transform_html(File.join(opt(:external), 'Documentation', 'Extensions.html'), File.join(ext_doc_dir, 'Extensions.html')) unless nothing_personal
    end
    
    def reindex
      Find.find(@dir.join('Index')) do |path|
        next unless path.match(/(Index\/.*\.html)\Z/)
        transform_html(path, File.join(@index_root,$1), override: true)
      end
    end

    def compile(options={})
      if compile_ni(options)
        if compile_inform6(options)
          compile_cblorb(options)
          if opt(:zterp) and ('zcode' == opt(:format))
            system(opt(:zterp), up_to_date(blorb, output, override: true) ? blorb : output)
          elsif opt(:gterp) and ('glulx' == opt(:format))
            system(opt(:gterp), up_to_date(blorb, output, override: true) ? blorb : output)
          end
        end
      elsif opt(:browser) and File.exist?(@build.join('problems.html'))
        system(opt(:browser), @build.join('problems.html').to_s)
      end
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

    # TODO Metadata.ifiction manifest.plist Release.blurb index.html
    def clean(except=[])
      exceptions = except.map {|e| Pathname.new(e).expand_path.to_s }.to_set
      pp exceptions
      Find.find(@materials).select {|f| File.exist?(f) and f.end_with?('.eps') }.each {|g| File.unlink(g) }
      
      [ @dir.join('Index'), @index_root, @build ].each do |dirty|
        Find.find(dirty) do |path|
          next if Dir.exist?(path)
          absolute_path = Pathname.new(path).expand_path.to_s
          if exceptions.member?(absolute_path)
            puts "skipping #{absolute_path}"
          else
            puts "removing #{path}"
            FileUtils.rm_rf(path)
          end
        end
        Dir[File.join(dirty, '*')].each do |removable|
          removable = Pathname.new(removable).expand_path.to_s
          unless exceptions.member?(removable)
            puts "removing #{removable}"
            FileUtils.rm_r(removable)
          end
        end
      end
    end

    def check_executable(name)
      opt(name) || Inf7::Project.check_executable(name)
#      opt(name) || (TTY::Which.exist?(executable_name(name)) ? TTY::Which.which(executable_name(name)) : nil)
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
    
    def check_executable_or_die(name)
      location = check_executable(name)
      Optimist.die "Can't find #{name}: it must be specified, in settings, or in PATH" unless location
      location
    end

    def compile_ni(options)
      ni = check_executable_or_die(:ni)
#      if (File.exist?(@inf) and File.size(@inf).zero?) or !up_to_date(@source, @inf) or Dir[File.join(@extensions_dir, '*', '*.i7x')].any? {|ext| !up_to_date(ext, @source) }
      arg_list = []
      i7flags = options.key?(:i7flags)  ? options[:i7flags] : (options[:release] ? opt(:i7flagsrelease) : opt(:i7flagstest))
      arg_list << i7flags if !i7flags.empty?
      { nobble_rng: :rng, release: :release }.each_pair {|k,v| arg_list << "--#{v}" if opt(k) }
      %i{ index progress }.each {|s| arg_list << "--no#{s}" if !opt(s) }
      arg_list += [ '--internal', opt(:internal), '--external', opt(:external), '--project', dir.to_s ]
      report ([ni]+arg_list).join(' ')
      FileUtils.mkdir_p(opt(:external))
      stdout, stderr, rc = Open3.capture3(ni, *arg_list)
      %w{ Problems StatusCblorb }.each do |basename|
        filename = @build.join("#{basename}.html").to_s
        transform_html(filename, @build.join("#{basename.downcase}.html"), override: true) if File.exist?(filename)
      end
      make_source_html unless options[:temp]
      if File.exist?(@build.join("Debug log.txt")) and up_to_date(@inf, @build.join("Debug log.txt"), override: true)
        Inf7::Template.write(:generic_page, @build.join('debug_log.html'), name: "#{@name} Debug Log", head: "Debug Log for #{@name}", text: File.read(@build.join('Debug log.txt')).gsub(/#{$/}#{$/}+/,$/*2).gsub(%r{#{$/}}, "<br>"))
      end
      if rc.exitstatus and rc.exitstatus.zero? # on SIGSEGV exitstatus is nil
        update_project_extension_docs(force: options[:force]) unless options[:temp]
        out_lines = stdout.split($/)
        out_lines[1].match(/source text, which is (\d+) words long\./)
        word_count = $1
        out_lines[-2].match(/(There were.*things\.)/)
        room_thing_count = $1
        report opt(:verbose) ? stdout : "Compiled #{word_count}-word source. #{room_thing_count}"
        reindex if opt(:index)
      else
        STDERR.puts "Failed"
        STDERR.puts(stdout) if stdout
        STDERR.puts(stderr) if stderr
        # error_count = stdout ? (stdout.split(%r{#{$/}\s+>-->\s+}).count - 1) : 0
        return false
      end
      make_fakes if @conf[:fake]
      return true
      #      else
      #        report "#{@inf} up to date"
      #        return true
      #      end
    end

    def compile_inform6(options)
      report # output newline
      i6flags_arg = options[:i6flags] ? options[:i6flags] : (options[:release] ? opt(:i6flagsrelease) : opt(:i6flagstest))
  #    if up_to_date(inf, output)
  #      report "#{output} up to date"
  #      return true
  #    else
        inform6 = check_executable_or_die(:inform6)
        report "#{inform6} #{i6flags_arg}#{i6flag} #{inf} #{output}"
        stdout, stderr, rc = Open3.capture3(inform6, "#{i6flags_arg}#{i6flag}", inf.to_s, output.to_s)
        if rc.exitstatus and rc.exitstatus.zero?
          report opt(:verbose) ? stdout : stdout.split($/).select {|l| l.match(/\A(Inform|In:|Out:)/) }.join("\n")
        else
          STDERR.write(stdout) if stdout
          STDERR.write(stderr) if stderr
          return false
        end
        make_fakes if @conf[:fake]
        return true
   #   end
    end

    def compile_cblorb(options)
      return true unless opt(:create_blorb)
      report # output newline
      cblorb = check_executable_or_die(:cblorb)
      # TODO to check blorb mtime we need to check everything in Release
    #  if up_to_date(output, blorb)
    #    report "#{blorb} up to date"
    #  else
        report "#{cblorb} #{opt(:cblorbflags)} #{release_blurb} #{blorb}"
        stdout, stderr, rc = Open3.capture3(cblorb, opt(:cblorbflags), release_blurb.to_s, blorb.to_s)
        if rc.exitstatus and rc.exitstatus.zero?
          report opt(:verbose) ? stdout : stdout.split($/).map {|l| l.match(/\A!\s+((cBlorb|Completed).*)/); $1}.compact.join("\n")
        else
          STDERR.puts(stdout) if stdout
          STDERR.puts(stderr) if stderr
          return false
        end
        make_fakes if @conf[:fake]
        return true
     # end
    end

    def up_to_date(file1, file2, force: false, override: false)
      return false if (force or opt(:force)) and !override
      File.exist?(file2) and (File.mtime(file2) >= File.mtime(file1))
    end
    
    def cli_ize(str)
      str.downcase.gsub(/[^-\w]/,'_').gsub(/_+/,'_')
    end

  end
end
