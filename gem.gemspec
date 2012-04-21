# -*- encoding: utf-8 -*-
Gem::Specification.new do |gem|
  gem.name          = "gem"
  gem.author        = "Samuel Cochran"
  gem.email         = "sj26@sj26.com"
  gem.description   = %q{Just enough not-Rubygems to index a collection of gems for download... and maybe more.}
  gem.summary       = %q{Not-rubygems}
  gem.homepage      = "https://github.com/sj26/gem"

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- test/*`.split("\n")
  gem.require_paths = ["lib"]
  gem.version       = "0.0.1.alpha"
end
