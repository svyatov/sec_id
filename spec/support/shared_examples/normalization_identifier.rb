# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers

# Shared examples for normalization-based identifiers (CIK, OCC).
# Validates the core API: valid?, valid_format?, normalize!.
#
# @param valid_id [String] a valid, normalized identifier
# @param unnormalized_id [String] a valid but unnormalized identifier
# @param normalized_id [String] the expected normalized form
# @param invalid_id [String] an invalid identifier
RSpec.shared_examples 'a normalization identifier' do |params|
  let(:identifier_class) { described_class }
  let(:valid_id) { params[:valid_id] }
  let(:unnormalized_id) { params[:unnormalized_id] }
  let(:normalized_id) { params[:normalized_id] }
  let(:invalid_id) { params[:invalid_id] }

  describe 'instance methods' do
    context 'when identifier is valid and normalized' do
      let(:instance) { identifier_class.new(valid_id) }

      it 'returns true for #valid?' do
        expect(instance.valid?).to be(true)
      end

      it 'returns true for #valid_format?' do
        expect(instance.valid_format?).to be(true)
      end
    end

    context 'when identifier is valid but unnormalized' do
      let(:instance) { identifier_class.new(unnormalized_id) }

      it 'returns true for #valid?' do
        expect(instance.valid?).to be(true)
      end

      it 'returns true for #valid_format?' do
        expect(instance.valid_format?).to be(true)
      end

      it 'normalizes with #normalize!' do
        expect(instance.normalize!).to eq(normalized_id)
      end
    end

    context 'when identifier is invalid' do
      let(:instance) { identifier_class.new(invalid_id) }

      it 'returns false for #valid?' do
        expect(instance.valid?).to be(false)
      end

      it 'raises error for #normalize!' do
        expect { instance.normalize! }.to raise_error(SecId::InvalidFormatError)
      end
    end
  end

  describe 'class methods' do
    describe '.valid?' do
      it 'returns true for valid normalized identifier' do
        expect(identifier_class.valid?(valid_id)).to be(true)
      end

      it 'returns true for valid unnormalized identifier' do
        expect(identifier_class.valid?(unnormalized_id)).to be(true)
      end

      it 'returns false for invalid identifier' do
        expect(identifier_class.valid?(invalid_id)).to be(false)
      end
    end

    describe '.valid_format?' do
      it 'returns true for valid normalized identifier' do
        expect(identifier_class.valid_format?(valid_id)).to be(true)
      end

      it 'returns true for valid unnormalized identifier' do
        expect(identifier_class.valid_format?(unnormalized_id)).to be(true)
      end
    end

    describe '.normalize!' do
      it 'normalizes valid identifier' do
        expect(identifier_class.normalize!(valid_id)).to eq(normalized_id)
      end

      it 'normalizes unnormalized identifier' do
        expect(identifier_class.normalize!(unnormalized_id)).to eq(normalized_id)
      end

      it 'raises error for invalid identifier' do
        expect { identifier_class.normalize!(invalid_id) }.to raise_error(SecId::InvalidFormatError)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
