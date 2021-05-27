module Inf7
  class Extension
    def self.author_extbase(pathname)
      author_dir, ext_name = Pathname.new(pathname).split[-2,2]
      author_dir = author_dir.basename.to_s
      ext_name = ext_name.to_s.gsub(/\..*\Z/,'')
      [ author_dir, ext_name ]
    end
  end
end
