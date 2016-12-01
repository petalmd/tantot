# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tantot/version'

Gem::Specification.new do |spec|
  spec.name          = "tantot"
  spec.version       = Tantot::VERSION
  spec.authors       = ["François-Pierre Bouchard"]
  spec.email         = ["fpbouchard@gmail.com"]

  spec.summary       = %q{Allows to perform batched operations on model updates}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/petalmd"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($RS)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'database_cleaner'

  spec.add_dependency 'activesupport', '>= 3.2'
  spec.add_dependency 'activerecord', '>= 3.2'
end
