module Inf7
  class Doc
    Insertions =
      { wi: {
          2 => { 10 => :public_library },
            15 => :bug_tracker },
          10 => { 4 =>  :during_a_scene },

          19 => { 7 =>  :during_a_scene },
          25 => { 12 => :public_library },
          25 => { 12 => :public_library },
          27 => { 1 => :public_library,
           3 => :public_library },

        },
        rb: {           12 => { 5 => :public_library, },
}
      }
              

    
    Addenda =
      { during_a_scene: %Q{A known bug in 6M62 is that "during ...a scene..." produces an abject failure. As a workaround, use "when ...a scene... is happening" instead.},
        bug_tracker: %Q{<a href="http://inform7.com/support/">There is no longer a publicly available bug tracker</a>. Bugs for the IDEs may be reported as follows: <ul><li><a href="https://intfiction.org/t/gnome-inform7-6l38-6m62-ide-now-running-on-modern-ubuntu-fedora-os/43329/">Gnome IDE for Linux bugs</a></li><li><a href="https://github.com/TobyLobster/Inform">Mac OS IDE bugs</a><li><li><a href="https://github.com/DavidKinder/Windows-Inform7">Windows IDE bugs</a><li></ul>. There is no way to report bugs regarding ni, the Inform 7 compiler itself.},

        public_library: %Q{The Public Library has been disconnected. The <a href="https://i7.github.io/extensions/">Friends of I7 Extensions Github repo</a> is the best source of extensions.},
        
        

        
      }

       
  end
end
