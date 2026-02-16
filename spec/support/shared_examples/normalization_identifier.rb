# frozen_string_literal: true

# Shared examples for normalization across all identifier types.
# Validates instance methods (#normalized, #normalize, #normalize!) and class-level .normalize.
#
# @param valid_id [String] a valid identifier
# @param canonical_id [String] the expected canonical form (defaults to valid_id)
# @param dirty_id [String] a valid identifier with separators/whitespace/case issues
# @param invalid_id [String] an invalid identifier
RSpec.shared_examples 'a normalizable identifier' do |params|
  let(:identifier_class) { described_class }
  let(:valid_id) { params[:valid_id] }
  let(:canonical_id) { params.fetch(:canonical_id, params[:valid_id]) }
  let(:dirty_id) { params[:dirty_id] }
  let(:invalid_id) { params[:invalid_id] }

  describe '#normalized' do
    it 'returns a String' do
      expect(identifier_class.new(valid_id).normalized).to be_a(String)
    end

    it 'returns canonical string for valid input' do
      expect(identifier_class.new(valid_id).normalized).to eq(canonical_id)
    end

    it 'raises for invalid input' do
      expect { identifier_class.new(invalid_id).normalized }.to raise_error(SecId::Error)
    end
  end

  describe '#normalize' do
    it 'returns the same value as #normalized' do
      instance = identifier_class.new(valid_id)
      expect(instance.normalize).to eq(instance.normalized)
    end
  end

  describe '#normalize!' do
    it 'returns self' do
      instance = identifier_class.new(valid_id)
      expect(instance.normalize!).to equal(instance)
    end

    it 'mutates full_number to canonical form' do
      instance = identifier_class.new(valid_id)
      instance.normalize!
      expect(instance.full_number).to eq(canonical_id)
    end

    it 'is idempotent' do
      instance = identifier_class.new(valid_id)
      instance.normalize!
      first_full_number = instance.full_number
      instance.normalize!
      expect(instance.full_number).to eq(first_full_number)
    end

    it 'raises for invalid input' do
      expect { identifier_class.new(invalid_id).normalize! }.to raise_error(SecId::Error)
    end
  end

  describe '.normalize' do
    it 'returns a String' do
      expect(identifier_class.normalize(valid_id)).to be_a(String)
    end

    it 'returns canonical string for valid input' do
      expect(identifier_class.normalize(valid_id)).to eq(canonical_id)
    end

    it 'handles separator-dirty input' do
      expect(identifier_class.normalize(dirty_id)).to eq(canonical_id)
    end

    it 'raises for invalid input' do
      expect { identifier_class.normalize(invalid_id) }.to raise_error(SecId::Error)
    end
  end
end
