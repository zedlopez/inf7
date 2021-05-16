# inf7 Installation

inf7 requires ruby (it was developed on ruby 2.7.3) and the bundler gem.

```
$ sudo apt install ruby
```

should be adequate on Debian or Debian-derived distros to install the system dependencies.

This is probably the easiest way to install without requiring elevated permissions. Assuming you have $HOME/bin in your PATH:

```
$ GEM_HOME="$HOME/gems" gem install inf7-0.1.0.gem
$ cp inf7.sh "$HOME/bin/inf7"
```

If you use a different value for GEM_HOME, you'll have to modify $HOME/bin/inf7 accordingly.

I don't recommend using ``sudo gem install`` and affecting your system-wide gem ecosystem.

From source:

```
$ git clone https://github.com/zedlopez/inf7.git
$ cd inf7
$ export GEM_HOME="$HOME/gems"
$ gem install bundler
$ bundle install
$ gem build inf7.gemspec
$ gem install inf7-0.1.0.gem
$ cp inf7.sh "$HOME/bin/inf7"
```
