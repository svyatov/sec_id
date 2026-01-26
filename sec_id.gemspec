# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sec_id/version'

Gem::Specification.new do |spec|
  spec.name          = 'sec_id'
  spec.version       = SecId::VERSION
  spec.authors       = ['Leonid Svyatov']
  spec.email         = ['leonid@svyatov.ru']

  spec.summary       = 'Validate securities identification numbers with ease!'
  spec.description   = 'Validate, calculate check digits, and parse components of securities identifiers. ' \
                       'Supports ISIN, CUSIP, CEI, SEDOL, FIGI, LEI, IBAN, CIK, OCC, WKN, Valoren, CFI, ' \
                       'and FISN standards.'
  spec.homepage      = 'https://github.com/svyatov/sec_id'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.require_paths = ['lib']
  spec.files = Dir['lib/**/*.rb'] + %w[CHANGELOG.md LICENSE.txt README.md sec_id.gemspec]

  spec.metadata['rubygems_mfa_required'] = 'true'
end
