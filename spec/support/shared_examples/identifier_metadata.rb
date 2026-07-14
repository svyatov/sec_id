# frozen_string_literal: true

# Shared examples for identifier metadata class methods.
# Validates that every identifier class exposes consistent metadata.
#
# @param full_name [String] expected full human-readable name
# @param id_length [Integer, Range] expected identifier length
# @param has_checksum [Boolean] whether the class includes Checkable
RSpec.shared_examples 'an identifier with metadata' do |params|
  describe 'metadata class methods' do
    it '.short_name returns the unqualified class name' do
      expect(described_class.short_name).to eq(described_class.name.split('::').last)
    end

    it '.full_name returns the expected name' do
      expect(described_class.full_name).to eq(params[:full_name])
    end

    it '.id_length returns the expected length' do
      expect(described_class.id_length).to eq(params[:id_length])
    end

    it '.example returns a valid identifier' do
      expect(described_class.valid?(described_class.example)).to be(true)
    end

    it '.example length is consistent with .id_length' do
      length = described_class.example.length
      id_length = described_class.id_length

      case id_length
      when Range
        expect(id_length).to cover(length)
      when Array
        expect(id_length).to include(length)
      else
        expect(length).to eq(id_length)
      end
    end

    it '.has_checksum? returns the expected value' do
      expect(described_class.has_checksum?).to be(params[:has_checksum])
    end
  end
end
