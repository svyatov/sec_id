# frozen_string_literal: true

# Shared examples for generatable identifiers.
# Validates that `.generate` returns a valid instance and respects a seeded Random.
RSpec.shared_examples 'a generatable identifier' do
  describe '.generate' do
    it 'returns an instance of the class' do
      expect(described_class.generate).to be_a(described_class)
    end

    it 'returns a valid identifier' do
      expect(described_class.generate).to be_valid
    end

    it 'returns a valid identifier across many seeds' do
      (1..250).each do |seed|
        expect(described_class.generate(random: Random.new(seed))).to be_valid
      end
    end

    it 'produces identical output for the same seed' do
      first = described_class.generate(random: Random.new(42)).to_s
      second = described_class.generate(random: Random.new(42)).to_s
      expect(first).to eq(second)
    end

    it 'produces different output for different seeds' do
      expect(described_class.generate(random: Random.new(42)).to_s)
        .not_to eq(described_class.generate(random: Random.new(7)).to_s)
    end
  end
end
