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

# Type signatures (sig/) — dev/test only; the gem keeps zero runtime dependencies.
gem 'rbs', '~> 4.0', require: false
gem 'steep', '~> 2.0', require: false

gem 'simplecov', '~> 0.22', require: false
gem 'simplecov-cobertura', require: false
