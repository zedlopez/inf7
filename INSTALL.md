# inf7 Installation

inf7 requires ruby (it was developed on ruby 2.7.3).

This is probably the easiest way to install without requiring elevated permissions. Assuming you have $HOME/bin in your PATH:

From source:

```
$ git clone https://github.com/zedlopez/inf7.git
$ cd inf7
$ export GEM_HOME="$HOME/gems"
$ gem build inf7.gemspec
$ gem install inf7-0.1.0.gem
$ cp inf7.sh "$HOME/bin/inf7"
```

If you use a different value for GEM_HOME, you'll have to modify $HOME/bin/inf7 accordingly. (I don't recommend using ``sudo gem install`` and affecting your system-wide gem ecosystem.)


