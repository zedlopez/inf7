# inf7 Installation

inf7 requires ruby (it was developed on ruby 2.7.3). If you want to be able to generate an epub of the documentation, you'll need [pandoc](https://pandoc.org/) as well. And if you want pygment-formatted source code for your story and extensions in the Project Index, you'll need Python and [pygments](https://pygments.org/).

This is probably the easiest way to install without requiring elevated permissions. Assuming you have $HOME/bin in your PATH:

From source:

```
$ git clone https://github.com/zedlopez/inf7.git
$ cd inf7
$ export GEM_HOME="$HOME/gems"
$ gem build inf7.gemspec
$ gem install inf7-0.1.6.gem
$ cp inf7.sh "$HOME/bin/inf7"
```

If you use a different value for GEM_HOME, you'll have to modify $HOME/bin/inf7 accordingly. (I don't recommend using ``sudo gem install`` and affecting your system-wide gem ecosystem.)

One way to ensure you have the prerequisites for pygment formatting would be:

```
$ cd $HOME
$ virtualenv --python=python3 pygments
$ cd pygments
$ source bin/activate
$ pip install pygments
$ cp $GEM_HOME/gems/inf7-0.1.6/i7tohtml bin
```

And then set i7tohtml to $HOME/pygments/bin/i7tohtml (but use the absolute pathname, not something with $HOME).




