# frozen_string_literal: true

RSpec.describe SecID::Checkable, :rbs_test_incompatible do
  [SecID::ISIN, SecID::CUSIP, SecID::CEI, SecID::FIGI].each do |klass|
    it "validates #{klass.short_name} with fewer than 20 allocations per call" do
      input = klass.example
      100.times { klass.valid?(input) }
      before = GC.stat(:total_allocated_objects)
      100.times { klass.valid?(input) }
      allocated = GC.stat(:total_allocated_objects) - before

      expect(allocated).to be < 2000
    end
  end
end
