# frozen_string_literal: true

require_relative 'lib/matrix_octoprint/version'

Gem::Specification.new do |spec|
  spec.name          = 'matrix_octoprint'
  spec.version       = MatrixOctoprint::VERSION
  spec.authors       = ['Alexander Olofsson']
  spec.email         = ['ace@haxalot.com']

  spec.summary       = 'Pass notifications and commands between Octoprint and Matrix'
  spec.homepage      = 'https://github.com/ananace/ruby-matrix_octoprint'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.6.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  spec.extra_rdoc_files = 'README.md'
  spec.files = Dir['{bin,lib}/**/*.rb'] + spec.extra_rdoc_files
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'faye-websocket', '~> 0.11'
  spec.add_dependency 'json'
  spec.add_dependency 'logging', '~> 2'
  spec.add_dependency 'matrix_sdk', '~> 2'

  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rubocop', '~> 1.7'
end
