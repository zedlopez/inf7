
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "inf7/version"

Gem::Specification.new do |spec|
  spec.name          = "inf7"
  spec.version       = Inf7::VERSION
  spec.authors       = ["Zed Lopez"]
  spec.email         = ["zed@zedlopez.org"]

  spec.summary       = %q{Inform 7 CLI project manager}
  spec.description   = %q{Create and compile Inform 7 projects}
  spec.homepage      = "https://github.com/zedlopez/inf7/"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  #   spec.metadata["homepage_uri"] = spec.homepage
  #   spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  #   spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against " \
  #     "public gem pushes."
  # end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake", "~> 10.0"
#  spec.add_dependency "rouge", "~> 3.26.0"
  spec.add_dependency "erubi", "~> 1.1.0"
  spec.add_dependency "xdg", "~> 5.1.1"
  spec.add_dependency "optimist", "~> 3.0.1"
#  spec.add_dependency "tty-which", "~> 
  spec.add_dependency "nokogiri", "~> 1.11.7"
  spec.add_dependency "tty-table", "~> 0.12.0"

end
