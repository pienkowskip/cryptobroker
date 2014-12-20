# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cryptobroker/version'

Gem::Specification.new do |spec|
  spec.name          = "cryptobroker"
  spec.version       = Cryptobroker::VERSION
  spec.authors       = ["pablo"]
  spec.email         = ["pienkowskip@gmail.com"]
  spec.description   = 'Gem for Crypto Currencies trading'
  spec.summary       = 'Gem for Crypto Currencies trading'
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
