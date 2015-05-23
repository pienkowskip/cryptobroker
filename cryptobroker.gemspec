# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cryptobroker/version'

Gem::Specification.new do |spec|
  spec.name          = 'cryptobroker'
  spec.version       = Cryptobroker::VERSION
  spec.authors       = ['Paweł Peńkowski']
  spec.email         = ['pienkowskip@gmail.com']
  spec.summary       = 'Gem for Crypto Currencies trading'
  spec.description   = <<-EOF
    Cryptobroker is a Crypto Currencies trading platform. Different trading strategies based on histogram indicators
    (MACD, DEMA, filters). You can implement own strategy. Available API for cex.io.
  EOF
  spec.homepage      = 'https://github.com/pienkowskip/cryptobroker'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = ['cryptobroker']
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activerecord', '~> 4.2', '>= 4.2.1'
  spec.add_runtime_dependency 'ta-indicator', '~> 0.1'
  spec.add_runtime_dependency 'net-http-persistent', '~> 2.9'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'gnuplot', '~> 2.6'
  spec.add_development_dependency 'pry', '~> 0.10'
  spec.add_development_dependency 'pg', '~> 0.17'
end
