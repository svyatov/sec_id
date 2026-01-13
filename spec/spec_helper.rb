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
end
