# frozen_string_literal: true

require 'open3'

# AE6 / R1 / R2 (negative): the default `require 'sec_id'` path must load no ActiveModel or Rails
# code and define no validator. Verified in a fresh subprocess because the main test process has
# already loaded the adapter and Rails via other specs.
RSpec.describe "require 'sec_id' isolation" do # rubocop:disable RSpec/DescribeClass
  it 'loads no validator, Railtie, ActiveModel, or Rails' do
    libdir = File.expand_path('../../lib', __dir__)
    script = <<~RUBY
      require 'sec_id'
      leaked = defined?(SecIdValidator) || defined?(SecID::Railtie) || defined?(ActiveModel) || defined?(Rails)
      exit(leaked ? 1 : 0)
    RUBY

    out, status = Open3.capture2e(RbConfig.ruby, '-I', libdir, '-e', script)

    expect(status.exitstatus).to eq(0), out
  end
end
