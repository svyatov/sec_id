# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

Rake::Task['release:rubygem_push'].enhance(['fetch_otp'])

task :fetch_otp do
  ENV['GEM_HOST_OTP_CODE'] = `op item get "RubyGems" --account my --otp`.strip
end

desc 'Run validation/detection throughput and allocation benchmarks'
task :bench do
  ruby '-Ilib benchmark/run.rb'
end

task default: %i[rubocop spec]
