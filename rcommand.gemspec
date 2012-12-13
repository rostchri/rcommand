# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rcommand/version'

Gem::Specification.new do |gem|
  gem.name          = "rcommand"
  gem.version       = Rcommand::VERSION
  gem.authors       = ["Christian Rost"]
  gem.email         = ["chr@baltic-online.de"]
  gem.description   = %q{Using ssh to execute some commands remotely}
  gem.summary       = %q{Using ssh to execute some commands remotely}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  
  gem.add_dependency "net-ssh"
  gem.add_dependency "net-ssh-gateway"
end
