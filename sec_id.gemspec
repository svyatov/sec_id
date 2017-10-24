# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sec_id/version'

Gem::Specification.new do |spec|
  spec.name          = 'sec_id'
  spec.version       = SecId::VERSION
  spec.authors       = ['Leonid Svyatov']
  spec.email         = ['leonid@svyatov.ru']

  spec.summary       = 'Validate security identification numbers with ease!'
  spec.description   = %(#{spec.summary} Currently supported standards: ISIN, CUSIP, SEDOL, IBAN.)
  spec.homepage      = 'https://github.com/svyatov/sec_id'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 2.3.0'

  spec.require_paths = ['lib']
  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.7'
  spec.add_development_dependency 'rubocop', '~> 0.51'
  spec.add_development_dependency 'rubocop-rspec', '~> 1.19'
  spec.add_development_dependency 'simplecov', '~> 0.15'
end
