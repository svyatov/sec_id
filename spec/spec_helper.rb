# frozen_string_literal: true

require 'bundler/setup'

if ENV['COVERAGE']
  require 'simplecov'

  if ENV['CI']
    require 'simplecov_json_formatter'
    SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
  end

  SimpleCov.start do
    add_filter { |src| !src.filename.start_with?("#{SimpleCov.root}/lib") }
  end
end

require 'sec_id'

# Load all support files (shared examples, shared contexts, etc.)
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Under RBS::Test (rake rbs:test), skip examples that are incompatible with its
  # runtime instrumentation — performance/timing budgets (hook overhead), alias
  # identity via #method (hooks wrap aliases separately), and missing-keyword
  # ArgumentError assertions (the type hook pre-empts Ruby's own error). These
  # exercise runtime behavior, not signature conformance.
  config.filter_run_excluding(:rbs_test_incompatible) if ENV['RBS_TEST_TARGET']
end
