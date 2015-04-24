# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cryptobroker/version'

Gem::Specification.new do |spec|
  spec.name          = 'cryptobroker'
  spec.version       = Cryptobroker::VERSION
  spec.authors       = ['Paweł Peńkowski']
  spec.email         = ['pienkowskip@gmail.com']
  spec.description   = 'Gem for Crypto Currencies trading'
  spec.summary       = 'Gem for Crypto Currencies trading'
  spec.homepage      = 'https://github.com/pienkowskip/cryptobroker'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activerecord', '~>4.2.1'
  spec.add_runtime_dependency 'ta-indicator'
  spec.add_runtime_dependency 'net-http-persistent'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'gnuplot'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pg'
end
