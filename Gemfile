# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in sec_id.gemspec
gemspec

# Specify your gem's development dependencies below
gem 'rake', '>= 13'

# ActiveModel/Rails validator (sec_id/active_model) — dev/test only; never a runtime dependency.
# The gemfiles/*.gemfile variants eval this file and pin activemodel/railties per Rails version, so
# declare them here (unpinned, tracking the latest) only for the default root Gemfile run.
unless ENV['BUNDLE_GEMFILE'].to_s.include?('gemfiles/')
  gem 'activemodel'
  gem 'railties'
end

gem 'benchmark-ips', '~> 2.0', require: false

gem 'rspec', '~> 3.9'
gem 'rspec_junit_formatter'

gem 'rubocop', '~> 1.88.0'
gem 'rubocop-rspec', '~> 3.10.0'

# RuboCop pulls parallel in transitively, and parallel 2.x requires Ruby >= 3.3. One
# lockfile is installed frozen on every Ruby in the CI matrix, down to 3.2, so the whole
# resolution has to stay installable there. Lift this when required_ruby_version does.
gem 'parallel', '< 2', require: false

# Type signatures (sig/) — dev/test only; the gem keeps zero runtime dependencies.
#
# rbs is held at 4.0.x: 4.1 retyped `Array#to_h`'s block return from the tuple `[K, V]` to the
# `Hash::_Pair[K, V]` interface, and Steep 2.0 cannot infer an array literal as a tuple against an
# interface hint, so `CFI::AttributeSet#to_h` stops type-checking. Tracked upstream in
# https://github.com/soutaro/steep/issues/2253 — drop the patch pin once a Steep release fixes it.
gem 'rbs', '~> 4.0.3', require: false
gem 'steep', '~> 2.0', require: false

# API documentation (rake yard) and the 100%-coverage gate (rake yard:stats) — dev/test only.
gem 'yard', '~> 0.9', require: false

gem 'simplecov', '~> 1.0', require: false
gem 'simplecov-cobertura', require: false
