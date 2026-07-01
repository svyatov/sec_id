# frozen_string_literal: true

RSpec.describe 'sec_id.gemspec' do # rubocop:disable RSpec/DescribeClass
  subject(:gemspec) { Gem::Specification.load(File.expand_path('../sec_id.gemspec', __dir__)) }

  # R4: ActiveModel/Rails are dev/test dependencies only; the gem's core stays zero-dependency.
  it 'declares no runtime dependencies' do
    expect(gemspec.dependencies.select(&:runtime?)).to be_empty
  end
end
