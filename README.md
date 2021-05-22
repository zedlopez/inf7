# inf7

## An Inform 7 project manager for the command line

inf7's aspirations:

- take the pain out of working with [Inform 7](https://inform7.com) on the command line
- provide an easy to browse, read, and search version of the Inform 7 docs
- give CLI users convenient access to the compiler-generated Project Index

## Introduction

Here's a sample session:

```
$ cd ~/inform
$ inf7 init "A Walk in the Park"
Created /home/zed/inform/A Walk in the Park.inform
$ emacs A\ Walk\ in\ the\ Park.inform/Source/story.ni
$ inf7 compile A\ Walk\ in\ the\ Park
/usr/local/bin/ni --noprogress --internal /usr/local/share/inform7/Internal --external /home/zed/external --project /home/zed/inform/A Walk in the Park.inform
Compiled 23-word source.

/usr/local/bin/inform6 -wE2SDG /home/zed/inform/A Walk in the Park.inform/Build/auto.inf /home/zed/inform/A Walk in the Park.inform/Build/output.ulx
Inform 6.34 for Linux (21st May 2020)
In:  1 source code files             66296 syntactic lines
Out:   Glulx story file 1.210503 (537.5K long):

/usr/local/bin/cBlorb -unix /home/zed/inform/A Walk in the Park.inform/Release.blurb /home/zed/inform/A Walk in the Park.inform/Build/output.gblorb
cBlorb 1.2 [executing on Monday 3 May 2021 at 13:44.58]
Completed: wrote blorb file of size 642210 bytes (1 picture(s), 0 sound(s))
```

You can specify the project directory by absolute or relative path; if you omit '.inform' from the end, as above, inf7 will automatically add it. As demonstrated above, the default output is terser than the commands' native output. You can get the undiluted output instead with the compile subcommand's ``--verbose`` flag (or suppress non-error output altogether with ``--quiet``).

After a successful compilation, you could run A Walk in the Park.inform/Build/output.ulx (or output.gblorb) in an interpreter, or open 'A Walk in the Park.inform/index.html' in your browser to see the Project Index. 

```
$ firefox "A Walk in the Park.inform/index.html"
```

All internal links to your story's source, installed extensions, or documentation will work. If you select the one of the text icons that paste code directly into the source window in the IDE, the corresponding text will be copied to the clipboard instead; you could then paste it into your editor.

After compilation, a problems.html file (with appropriately rewritten links) is created alongside the original Problems.html in the Build directory; check it for easy access to the bits of documentation the compiler thought were relevant to the errors.

```
$ firefox "A Walk in the Park.inform/Build/problems.html"
```

## Usage

You can ask inf7 for help to get a list of subcommands:

```
$ inf7 --help
Usage:
  inf7 [options] [command] [command options] [project]
Options:
  --version     print version and exit
  -h, --help    show help

Commands:
  setup      Set up inf7 environment (do this first)
  init       Initialize project
  compile    Compile project
  settings   See project settings
  set        Modify project settings
  install    Install extension for project
  ext        Create extension for project
  fake       Create a fake equivalent to a project
  doc        Regenerate documentation
  epub       Create epub
```

You can also ask for help on any of the subcommands. ``--help`` must come _after_ the subcommand.

```
$ inf7 settings --help
Options for settings
  --project     Project-local settings
  --user        User-wide settings
  --defaults    Default settings
  --all         Project, user, and default settings
  -h, --help    Show this message
```

If you specify a project, it is always the last thing on the line. Projects are the only thing that are specified _without_ some particular command-line flag.

## Installation

inf7 is written in Ruby, so your system will need at least that. See [INSTALL.md](./INSTALL.md) for installation details. 

## Getting started

You will need a working Inform 7 installation (more specifically, you'll need ni, inform6, and cBlorb executables and the Internal, Resources, and Documentation directories mentioned below).

Before you can do anything else, you have to run setup. This step's a little fiddly and annoying, but this annoyance is front-loaded: all the things you set here you won't have to worry about again.

The following are required:

- internal -- Inform 7's Internal Directory (parent dir of "Extensions/Graham Nelson/Standard Rules.i7x" at al)
- resources -- parent dir of doc_images, map_icons, scene_icons, bg_images, outcome_images
- docs -- contains Rdoc1.html through Rdoc103.html, doc1.html through doc459.html, and general_index.html
- external -- Inform 7's external directory (parent dir of the Extensions directory accessible to all your projects)

external and internal will be familiar to any command-line users of ni: they're the same values you pass to it. Places you'd expect resources:

- linux CLI package: /usr/local/share/inform7/Documentation (not named Resources)
- gnome package: /usr/share/gnome-inform7/Resources
- Mac OS: Inform/Inform.app/Contents/Resources 
- Windows: "Program Files\Inform 7\Documentation"

Places you'd expect docs:

- gnome package: /usr/share/gnome-inform7/Documentation
- Mac OS: Inform/Inform.app/Contents/Resources/English.lproj
- Windows: "Program Files\Inform 7\Documentation"

If you only have the Linux CLI package, you don't have the docs directory. You can find it in this [LZMA compressed archive of the Inform 7 data](https://github.com/ptomato/gnome-inform7/raw/master/data/Inform_6M62_data.tar.lz). You may have to rename it to end .xz instead of .lz for tar to be able to extract its contents. This archive has top-level Documentation and Resources directories appropriate for --docs and --resources. (The Linux CLI package has the equivalent documentation contents but with more readable filenames; the Project Index uses the less readable filenames internally.)

Not strictly required, but you'll probably want to specify the author tag or you'll get the default of "Imp".

author -- default author for new stories and extensions. 

You may specify the locations of ni, inform6, and cBlorb here, but if they're in your PATH you don't have to (see Executables below). 

The default for cblorbflags is '-unix'. Mac users will want to set it to '-osx' and Windows users to '-windows'.

There are many other options; we'll get to them later.

```
$ inf7 setup --internal /usr/local/share/inform7/Internal --external ~/external --resources /usr/share/gnome-inform7/Resources --docs /usr/share/gnome-inform7/Documentation --author "Zed Lopez"
```

## Files

inf7 stores info in:

- $XDG_CONFIG_HOME/inf7 (or $HOME/.config/inf7 if XDG_CONFIG_HOME isn't specified)
- $XDG_DATA_HOME/inf7  (or $HOME/.local/share/inf7 if XDG_DATA_HOME isn't specified)

The principal file in the config dir is inf7.yml, which stores the info you specified in your setup. As a YAML file, it's human-readable and (with care) human-editable; editing the file is the only way to change your setup. The config dir also contains a tmpl directory (more on this later).

The data dir contains inf7's rewritten version of the Inform 7 documentation. This is normally created just once on setup, but the doc subcommand regenerates it if desired.

## Inform 7 docs

The rewritten documentation lives in a doc dir under the data dir. You can access it with, e.g.,

file:///home/user/.local/share/inf7/doc/index.html

All of its internal links are relative, so the whole doc dir could be put somewhere a web server could serve from and it would just work.

That index.html provides just a Table of Contents and the General Index and there's a web page for each chapter of Writing with Inform and The Recipe Book. The examples appear only in The Recipe Book; references to them in Writing in Inform link to them. The examples appear in collapsible boxes that are closed by default.

There's also a monolithic one.html file comprising the whole thing, thus facilitating searching the documentation via "find in page" in your browser. Since your browser's search won't find the content of closed boxes, use the 'Open all examples' link at the top first if you want your search to include them.

If you have [pandoc](https://pandoc.org/) installed, you can create a single epub of the documentation with:

```
$ inf7 epub
```

It will be written to inform7.epub in the doc subdirectory of the data dir. By including the examples only once and pruning the HTML it is only a little more than a third of the size of the epub that accompanied the official documentation.

## Creating a project

When you init a new project, you don't need to specify any parameters other than a name.

```
inf7 init "Astounding Journey"
```

This will create "Astounding Journey.materials" with Release and Extensions subdircetories and "Astounding Journey.inform" containing Settings.plist, uuid.txt, an empty Build directory, and a Source directory containing a story.ni file with the project name as its title and the author from the inf7.yml config file. The author can be changed on the command-line (any of setup's relevant config items may be specified on the init command-line and will persist as that project's settings).

You may specify the name with .inform, but you don't have to.

inf7 will work seamlessly with projects created by the IDE; the converse should be true as well (though of course if your most recent compilation was with the IDE, inf7's rewritten Project Index will be out of date).

```
inf7 init "Astounding Journey.inform"
```

### --top and --git

If you want the system to create the .inform and .materials directories under a new parent directory, you can specify the --top setting (and set it in setup or by modifying inf7.yml after setup if you always want that).

```
inf7 init --top "The Parent Trap"
```

This creates a "The Parent Trap" directory containing "The Parent Trap.inform" and "The Parent Trap.materials" (with the usual initial contents). One of the reasons you might want to do this is for ease of use with git; if that's what you're after, use the --git command-line flag. --git implies --top and it runs git init for you. (It doesn't add anything to the repo, though.)

```
inf7 init --git "Ice Cream Shoppe"
```

"Ice Cream Shoppe" has a .git subdirectory as well as "Ice Cream Shoppe.inform" and "Ice Cream Shoppe.materials". A .gitignore file is in place and ``git init`` has been run for you, but no files have been added in git. 

### Initial extensions

The inf7 config directory has an extensions subdirectory. If you put extensions there (with the author's name as parent directory, as usual), they'll be automatically copied to the extensions directory of any new projects. See Extensions for more information.

## Compiling a project

Most of the time compile won't need command-line flags until you want the ``--release`` flag, but you have the option of overriding any relevant project or config setting on the command-line if you want.

If you're in or under an Inform 7 project directory, inf7 defaults to operating on that project if you don't explicitly specify one. And if you don't specify a subcommand, it defaults to 'compile'. 

```
$ cd "A Walk in the Park.inform/Source"
$ inf7
/home/zed/inform/A Walk in the Park.inform/Build/auto.inf up to date
/home/zed/inform/A Walk in the Park.inform/Build/output.ulx up to date
/home/zed/inform/A Walk in the Park.inform/Build/output.gblorb up to date
```

As seen above, inf7 defaults to not generating files if their source files haven't been changed. If you want to recompile regardless of modification time, you can specify the ``--force`` parameter.

Other relevant parameters:

- --nobble-rng disable pseudorandomness (use ni's --rng parameter)
- --release compile for release
- --progress turn back on the noisy progress meter inf7 leaves off by default
- --format specify zcode if you want it; default is glulx 
- --no-create-blorb don't run cBlorb
- --no-index don't generate Project index
- --quiet don't produce any non-error output
- --verbose provide full output from ni, inform6, and cBlorb instead of inf7's shorter default
- --i7flags any additional command-line flags you want passed directly to ni
- --i6flags exact flags you want passed directly to inform6
- --cblorbflags exact flags you want passed directly to cBlorb

"i7flags" and "i6flags" only exist on the compile command-line, not in project or config settings. In project or config settings there are:

--i6flagstest
--i6flagsrelease
--i7flagstest
--i7flagsrelease

and which is used depends on whether you specify --release.

There's an important difference between how i6flags and i7flags work. i7flags is additive, but if you specify i6flags you must specify all the i6flags you want to apply to the run: what you specify _replaces_ the defaults.

### Compiling without a project

If you invoke compile and the last argument is a file ending .ni instead of an Inform project, inf7 will create a project in tempdirs to compile it. If the compilation is successful, it'll write the gamefile to the current directory with the same basename as the source, but with an ulx or z8 suffix as appropriate.

```
$ inf7 compile walk_in_the_park.ni # if successful, there will be a walk_in_the_park.ulx
```

### Executables

The compile subcommand will need to have access to ni, inform6, and cBlorb. If these exist in your PATH, you don't have to specify them. Otherwise, you'll want to specify them when you run setup. (If you really wanted, they could be configured on a per project basis or overridden with command-line options when you compile.)

## Set and Settings

Because inf7 creates and uses a Settings.plist file for compatibility with the IDE, project settings are split between Settings.plist and .rc.yml. To see all of a project's settings, use the settings command:

```
$ inf7 settings A\ Walk\ in\ the\ Park

A Walk in the Park project settings
  create_blorb: true
  format: glulx
  nobble_rng: false
```

Those three will always appear because they have explicit values in Settings.plist.

To find all applicable settings, including those from the config and the defaults in use if nothing is specified, add ``--all``.

```
$ inf7 settings --all A\ Walk\ in\ the\ Park

A Walk in the Park project settings
  create_blorb: true
  format: glulx
  nobble_rng: false

User-wide settings
  author: Zed Lopez
  internal: /usr/local/share/inform7/Internal
  external: /home/zed/external
  resources: /usr/share/gnome-inform7/Resources
  docs: /usr/share/gnome-inform7/Documentation
  top: false
  git: false
  quiet: false

Defaults
  i6flagstest: -wE2SD
  i6flagsrelease: -wE2~S~D
  i7flagstest:
  i7flagsrelease:
  cblorbflags: -unix
  blorbfile_basename: output
  index: true
  force: false
  progress: false
```

To set project-level things, you could edit .rc.yml and Settings.plist directly, but there's also a ``set`` subcommand.

```
$ inf7 set --format zcode A\ Walk\ in\ the\ Park
$ inf7 set --author "Sudo Nymme" A\ Walk\ in\ the\ Park
$ inf7 settings A\ Walk\ in\ the\ Park

A Walk in the Park project settings
  create_blorb: true
  format: zcode
  nobble_rng: false
  author: Sudo Nymme
```

There isn't an equivalent ability to modify the config; just edit inf7.yml manually.

## Templates

inf7 creates a lot of different files like the initial story.ni when you run init, or the a new extension when you run ext. The inf7 config directory has a tmpl directory with story.erb and extension.erb, [erubi templates](https://github.com/jeremyevans/erubi). If you'd like to customize the contents of these, you can edit them.

There are a lot of other files inf7 creates from templates; it always looks to the config directory for templates first. If it finds one there, it uses that one instead of its own default. If you want to customize the style of the documentation, copy style.erb to your config dir's tmpl subdirectory and modify it as you see fit. This gives considerable flexibility and commensurate ability to shoot yourself in the foot. But if you mess things up, you can always delete the config directory's copy and it'll go back to the default, or you can copy the default over the config's copy.

To customize the .gitignore new projects get, copy tmpl/gitignore.erb to your config dir's tmpl directory and edit that.

## Extensions

### Creating a new extension

The ext subcommand allows making a new extension.

```
$ inf7 ext --name "Flexible Fluids" "Astounding Journey"
```

You may specify an author command-line flag to override the project or config setting. The initial contents are from the extension template; see Templates for info on how to modify that.

As with installation, you'll have to include it manually to make use of it.

### Installing an existing extension

To install a particular extension in a particular project, or in your config dir for automatic inclusion in the extensions directories of subsequent projects, use the install command. The path specified for the extension must include the extension's author-named parent directory.

Installing for a particular project:

```
$ inf7 install --ext ~/inform/Emily\ Short/Deluxe\ Doors.i7x "A Walk in the Park"
```

This merely copies the extension to the project's extension directory; you'll have to manually put the include statement where you want.

If you're under that project's directory, the project name can be omitted, as usual.

To install in your config dir:

```
$ inf7 install --init --ext ~/inform/Dannii\ Willis/Xorshift.i7x
```

In either case, copying directly to the relevant directory works as well.

## Regenerating the docs

If you wish to regenerate the docs for an existing setup, use the doc subcommand.

```
$ inf7 doc
```

This would probably be of interest only after you've updated inf7 to a new version that has changed the doc rewriting code.

With the ``--active`` flag, doc rewrites just the active content: css and js. This would be of interest if you've modified the templates that generate them.

```
$ inf7 doc --active
```

## Fakery

Here's an alternative sample session:

```
$ cd a_walk_in_the_park
$ ls
a_walk_in_the_park.ni  extensions
$ inf7
/usr/local/bin/ni --noprogress --internal /usr/local/share/inform7/Internal --external /home/zed/external --project /home/zed/inform/A Walk in the Park.inform
Compiled 18-word source.

/usr/local/bin/inform6 -wE2SDG /home/zed/inform/A Walk in the Park.inform/Build/auto.inf /home/zed/inform/A Walk in the Park.inform/Build/output.ulx
Inform 6.34 for Linux (21st May 2020)
In:  1 source code files             66292 syntactic lines
Out:   Glulx story file 1.210506 (537.5K long):

/usr/local/bin/cBlorb -unix /home/zed/inform/A Walk in the Park.inform/Release.blurb /home/zed/inform/A Walk in the Park.inform/Build/output.gblorb
cBlorb 1.2 [executing on Thursday 6 May 2021 at 11:06.18]
Completed: wrote blorb file of size 642210 bytes (1 picture(s), 0 sound(s))
$ ls
a_walk_in_the_park.gblorb  a_walk_in_the_park.inf  a_walk_in_the_park.ni  a_walk_in_the_park.ulx  debug_log.txt  extensions  index.html  problems.html  release
```

Here's the trick:

```
% ls -l
total 36
lrwxrwxrwx 1 zed zed 83 May  5 21:05 a_walk_in_the_park.gblorb -> '/home/zed/inform/A Walk in the Park.inform/Build/output.gblorb'
lrwxrwxrwx 1 zed zed 78 May  5 21:05 a_walk_in_the_park.inf -> '/home/zed/inform/A Walk in the Park.inform/Build/auto.inf'
lrwxrwxrwx 1 zed zed 79 May  5 21:05 a_walk_in_the_park.ni -> '/home/zed/inform/A Walk in the Park.inform/Source/story.ni'
lrwxrwxrwx 1 zed zed 80 May  5 21:05 a_walk_in_the_park.ulx -> '/home/zed/inform/A Walk in the Park.inform/Build/output.ulx'
lrwxrwxrwx 1 zed zed 83 May  5 21:05 debug_log.txt -> '/home/zed/inform/A Walk in the Park.inform/Build/Debug log.txt'
lrwxrwxrwx 1 zed zed 77 May  5 21:05 extensions -> '/home/zed/inform/A Walk in the Park.materials/Extensions'
lrwxrwxrwx 1 zed zed 89 May  5 21:05 index.html -> '/home/zed/inform/A Walk in the Park.inform/.index/Index/Welcome.html'
lrwxrwxrwx 1 zed zed 83 May  5 21:05 problems.html -> '/home/zed/inform/A Walk in the Park.inform/Build/problems.html'
lrwxrwxrwx 1 zed zed 74 May  5 21:05 release -> '/home/zed/inform/A Walk in the Park.materials/Release'
```

If you feel like having this level of denial, it can be yours with:

```
$ inf7 fake --name a_walk_in_the_park "A Walk in the Park"
```

## Smoke testing an extension

The test subcommand has an ``--ext`` flag that takes an extension (specified including its author dir, as with the install subcommand). It creates a temporary project with a story file that includes the extension and tries compiling it. It takes most of the same parameters as init; in particular, be sure that ``--external`` is set appropriately for dependencies to be found.

```
$ inf7 test ~/external/

## Cleaning up

Besides all the files Inform 7 usually leaves behind, inf7 leaves more in its transformed Project Index. You can use the clean subcommand to remove all the contents of:

- the Inform 7 Build directory's contents
- the Inform 7 Index directory's contents
- inf7's own .index directory

```
$ inf7 clean a_walk_in_the_park
```

## Cautions

This is an alpha-release. I haven't yet used it to develop a real Inform project. While I don't know of any bugs, I'm sure they exist. The code attempts to be scrupulous about never clobbering any files except the ones it created and, of course, the ones normally clobbered by compilation and only the clean subcommand outright removes files, but I couldn't say it's impossible it could somehow damage your system.

The docs-munger and compiler-helper began as independent projects and with both of them I was figuring out what I wanted them to be as I went. The code sorely needs refactoring, which I've already begun, but it's usable as is so I wanted to share and solicit feedback.

Because it's an alpha release of a tool expected to be used by single developers on their personal projects, the current code isn't especially defensive and you will certainly be able to get bad behavior if you go out of your way to pass bad parameters.

## Questions / Comments / Bug Reports

For questions or general discussion, visit the [inf7 thread on the intfiction forums](https://intfiction.org/t/inf7-a-cli-project-manager-for-inform-7/50931).

You can submit [bug reports via Github](https://github.com/zedlopez/inf7/issues).

## Future development

I have a lot of plans. One of them is to refactor in a way that facilitates other projects' use of individual modules. The current implementation ended up too pervasively tied to its particular configuration scheme.

And maybe I'll even come up with a name that isn't so boring.

## Reference

For background on Inform 7 compilation CLI options, see [How to use ni, inform6, and cblorb by CLI](https://intfiction.org/t/command-line-inform-7-how-to-use-ni-inform6-and-cblorb-by-cli/50108).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
