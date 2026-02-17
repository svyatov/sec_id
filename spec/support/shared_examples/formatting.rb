# frozen_string_literal: true

# Shared examples for pretty formatting across all identifier types.
# Validates instance method #to_pretty_s and class-level .to_pretty_s.
#
# @param valid_id [String] a valid identifier
# @param dirty_id [String] a valid identifier with separators/whitespace/case issues
# @param invalid_id [String] an invalid identifier
RSpec.shared_examples 'a formattable identifier' do |params|
  let(:identifier_class) { described_class }
  let(:valid_id) { params[:valid_id] }
  let(:dirty_id) { params[:dirty_id] }
  let(:invalid_id) { params[:invalid_id] }

  describe '#to_pretty_s' do
    it 'returns a String for valid input' do
      expect(identifier_class.new(valid_id).to_pretty_s).to be_a(String)
    end

    it 'returns nil for invalid input' do
      expect(identifier_class.new(invalid_id).to_pretty_s).to be_nil
    end
  end

  describe '.to_pretty_s' do
    it 'returns a String for valid input' do
      expect(identifier_class.to_pretty_s(valid_id)).to be_a(String)
    end

    it 'handles separator-dirty input' do
      expect(identifier_class.to_pretty_s(dirty_id)).to eq(identifier_class.to_pretty_s(valid_id))
    end

    it 'returns nil for invalid input' do
      expect(identifier_class.to_pretty_s(invalid_id)).to be_nil
    end
  end
end
