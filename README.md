# inf7

## An Inform 7 project manager for the command line

inf7's aspirations:

- take the pain out of working with Inform 7 on the command line
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

/usr/local/bin/inform6 -wE2~SDG /home/zed/inform/A Walk in the Park.inform/Build/auto.inf /home/zed/inform/A Walk in the Park.inform/Build/output.ulx
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

All links to your story's source, installed extensions, or documentation will work. If you select the one of the text icons that paste code directly into the source window in the IDE, the corresponding text will be copied to the clipboard instead; you could then paste it into your editor.

After compilation, a problems.html file (with appropriately rewritten links) is created alongside the original Problems.html in the Build directory; check it for easy access to the bits of documentation the compiler thought were relevant to the errors.

```
$ firefox "A Walk in the Park.inform/Build/problems.html"
```

## help

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

And ask for help on any of the commands. ``--help`` must come _after_ the subcommand.

```
$ inf7 settings --help
Options for settings
  --project     Project-local settings
  --user        User-wide settings
  --defaults    Default settings
  --all         Project, user, and default settings
  -h, --help    Show this message
```

## Getting started

You will need a working Inform 7 installation (more specifically, you'll need ni, inform6, and cBlorb executables and the Internal, Resources, and Documentation directories mentioned below).

Before you can do anything else, you have to run setup. This step's a little fiddly and annoying, but this annoyance is front-loaded: all the things you set here you won't have to worry about again.

The following are required:

internal -- Inform 7's Internal Directory (parent dir of "Extensions/Graham Nelson/Standard Rules.i7x" at al)
resources -- parent dir of doc_images, map_icons, scene_icons, bg_images, outcome_images 
docs -- contains Rdoc1.html through Rdoc103.html, doc1.html through doc459.html, and general_index.html
external -- Inform 7's external directory (parent dir of the Extensions directory accessible to all your projects)

external and internal will be familiar to any command-line users of ni: they're the same flags you pass to it. Places you'd expect resources:

- linux CLI package: /usr/local/share/inform7/Documentation (not named Resources)
- gnome package: /usr/share/gnome-inform7/Resources
- Mac OS: Inform/Inform.app/Contents/Resources 
- Windows: TODO

Places you'd expect docs:

- gnome package: /usr/share/gnome-inform7/Documentation
- Mac OS: Inform/Inform.app/Contents/Resources/English.lproj
- Windows: TODO

If you only have the Linux CLI package, you don't have the docs directory. You can find it in this [LZMA compressed archive of the Inform 7 data](https://github.com/ptomato/gnome-inform7/raw/master/data/Inform_6M62_data.tar.lz). You may have to rename it to end .lzma instead of .lz for tar to be able to extract its contents. This archive has top-level Documentation and Resources directories appropriate for --docs and --resources. (The Linux CLI package has the equivalent documentation contents but with more readable filenames; the Project Index uses the less readable filenames internally.)

Not strictly required, but you'll probably want to specify the author tag.

author -- default author for new stories and extensions. 

You may specify the locations of ni, inform6, and cBlorb here, but if they're in your PATH you don't have to (see Executables below).

There are many other options; we'll get to them later.

TODO example command

## Files

inf7 stores info in:

- $XDG_CONFIG_HOME/inf7 (or $HOME/.config/inf7 if XDG_CONFIG_HOME isn't specified)
- $XDG_CACHE_HOME/inf7 (or $HOME/.cache/inf7 if XDG_CACHE_HOME isn't specified)
- $XDG_DATA_HOME/inf7  (or $HOME/.local/share/inf7 if XDG_DATA_HOME isn't specified)

The principal file in the config dir is inf7.yml, which stores the info you specified in your setup. As a YAML file, it's human-readable and (with care) human-editable; editing the file is the only way to change your setup. The config dir also contains a tmpl directory (more on this later).

The cache dir contains inf7's rewritten versions of the contents of the external directory's Documentation dir. These are updated as necessary on every compile. (You won't interact with these files directly; they're copied to your project after compilation.)

The data dir contains inf7's rewritten version of the Inform 7 documentation. This is normally created just once on setup, but the doc subcommand regenerates it if desired.

## Inform 7 docs

The rewritten documentation lives in a doc dir under the data dir. You can access it with, e.g.,

file:///home/user/.local/share/inf7/doc/index.html

All of its internal links are relative, so the whole doc dir could be copied somewhere a web server was configured to access and it would just work.

That index.html provides just a Table of Contents and the General Index and there's a web page for each chapter of Writing with Inform and The Recipe Book. But there's also a monolithic one.html file comprising the whole thing, thus facilitating searching the documentation via "find in page" in your browser.

The examples appear only in The Recipe Book; references to them in Writing in Inform link to them. 

If you have [pandoc](https://pandoc.org/) installed, you can create a single epub of the documentation with:

```
$ inf7 epub
```

It will be written to inform7.epub in the doc subdirectory of the data dir. By including the examples only once and pruning the HTML it is just over a third of the size of the epub that accompanied the official documentation.

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

This creates a "The Parent Trap" directory containing "The Parent Trap.inform" and "The Parent Trap.materials" (with the usual initial contents). One of the reasons you might want to do this is for ease of use with git; if that's what you're after, use the --git command-line flag. --git assumes --top and runs git init for you. (It doesn't add anything to the repo, though.)

```
inf7 init --git "Ice Cream Shoppe"
```

"Ice Cream Shoppe" has a .git subdirectory as well as "Ice Cream Shoppe.inform" and "Ice Cream Shoppe.materials". A .gitignore file is in place and ``git init`` has been run for you, but no files have been added in git. 

### Initial extensions

The inf7 config directory has an extensions subdirectory. If you put extensions there (with the author's name as parent directory, as usual), they'll be automatically copied to the extensions directory of any new projects. See Extensions for more information.

## Compiling a project

Most of the time compile won't need command-line flags until you want the ``--release`` flag. But you have the option of overriding any relevant project or config setting on the command-line if you want.

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

### Executables

The compile subcommand will need to have access to ni, inform6, and cBlorb. If these exist in your PATH, you don't have to specify them. Otherwise, you'll want to specify them when you run setup. (If you really wanted, they could be configured on a per project basis or overridden with command-line options when you compile.)

## Set and Settings

TODO

## Templates

inf7 creates a lot of different files like the initial story.ni when you run init, or the a new extension when you run ext. The inf7 config directory has a tmpl directory with story.erb and extension.erb, [erubi templates](https://github.com/jeremyevans/erubi). If you'd like to customize the contents of these, you can edit them.

There are a lot of other files inf7 creates from templates; it always looks to the config directory for templates first. If it finds one there, it uses that one instead of its own default. If you want to customize the style of the documentation, copy style.erb to your config dir's tmpl subdirectory and modify it as you see fit. This gives considerable flexibility and commensurate ability to shoot yourself in the foot. But if you mess things up, you can always delete the config directory's copy and it'll go back to the default, or you can copy the default over the config's copy.

To customize the .gitignore new projects get, copy tmpl/gitignore.erb to your config dir's tmpl directory and edit that.

## Extensions

TODO

### Install

To install a particular extension in a particular project, or in your config dir for automatic inclusion in the extensions directories of subsequent projects, use the install command. The path specified for the extension must include the extension's author-named parent directory.

Installing in a particular project:

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

### Creating a new extension

The ext subcommand allows making a new extension.

```
$ inf7 ext --name "Flexible Fluids" "Astounding Journey"
```

You may specify an author command-line flag to override the project or config setting. The initial contents are from the extension template; see Templates for info on how to modify that.

As with installation, you'll have to include it manually to make use of it.

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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/inf7. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Inf7 project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/inf7/blob/master/CODE_OF_CONDUCT.md).
