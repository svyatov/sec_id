# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sec_id/version'

Gem::Specification.new do |spec|
  spec.name          = 'sec_id'
  spec.version       = SecID::VERSION
  spec.authors       = ['Leonid Svyatov']
  spec.email         = ['leonid@svyatov.ru']

  spec.summary       = 'Validate securities identification numbers with ease!'
  spec.description   = %(#{spec.summary} Currently supported standards: ISIN, CUSIP, SEDOL.)
  spec.homepage      = 'https://github.com/svyatov/sec_id'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.require_paths = ['lib']
  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.metadata['rubygems_mfa_required'] = 'true'
end
