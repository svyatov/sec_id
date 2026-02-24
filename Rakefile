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

task default: %i[rubocop spec]
