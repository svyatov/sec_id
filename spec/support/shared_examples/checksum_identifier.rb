# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers

# Shared examples for checksum based identifiers (ISIN, CUSIP, SEDOL, FIGI, LEI, IBAN).
# Validates the core API: valid?, restore, restore!, checksum.
#
# @param valid_id [String] a valid identifier with correct checksum
# @param valid_id_without_check [String] a valid identifier without checksum (for restoration)
# @param restored_id [String] the expected full identifier after restoration
# @param invalid_format_id [String] an identifier with invalid format
# @param invalid_checksum_id [String] an identifier with wrong checksum
# @param expected_checksum [Integer, String] the expected checksum value
# @param expected_checksum_class [Class] the expected checksum type (default: Integer)
RSpec.shared_examples 'a checksum identifier' do |params|
  let(:identifier_class) { described_class }
  let(:valid_id) { params[:valid_id] }
  let(:valid_id_without_check) { params[:valid_id_without_check] }
  let(:restored_id) { params[:restored_id] }
  let(:invalid_format_id) { params[:invalid_format_id] }
  let(:invalid_checksum_id) { params[:invalid_checksum_id] }
  let(:expected_checksum) { params[:expected_checksum] }
  let(:expected_checksum_class) { params.fetch(:expected_checksum_class, Integer) }

  describe 'instance methods' do
    context 'when identifier is valid with correct checksum' do
      let(:instance) { identifier_class.new(valid_id) }

      it 'returns true for #valid?' do
        expect(instance.valid?).to be(true)
      end

      it 'returns a String for #restore' do
        result = instance.restore
        expect(result).to be_a(String)
        expect(result).to eq(valid_id)
      end

      it 'returns self for #restore!' do
        expect(instance.restore!).to equal(instance)
        expect(instance.full_id).to eq(valid_id)
      end

      it 'returns the expected type for #calculate_checksum' do
        result = instance.calculate_checksum
        expect(result).to be_a(expected_checksum_class)
        expect(result).to eq(expected_checksum)
      end
    end

    context 'when identifier is missing checksum' do
      let(:instance) { identifier_class.new(valid_id_without_check) }

      it 'returns false for #valid?' do
        expect(instance.valid?).to be(false)
      end

      it 'returns restored identifier string for #restore' do
        expect(instance.restore).to eq(restored_id)
      end

      it 'does not mutate instance for #restore' do
        instance.restore
        expect(instance.full_id).to eq(valid_id_without_check)
      end

      it 'does not mutate checksum for #restore' do
        original_checksum = instance.checksum
        instance.restore
        expect(instance.checksum).to eq(original_checksum)
      end

      it 'returns self for #restore!' do
        expect(instance.restore!).to equal(instance)
        expect(instance.full_id).to eq(restored_id)
      end

      it 'sets checksum for #restore!' do
        instance.restore!
        expect(instance.checksum).to eq(expected_checksum)
      end

      it 'calculates correct checksum' do
        expect(instance.calculate_checksum).to eq(expected_checksum)
      end
    end

    context 'when identifier has invalid checksum' do
      let(:instance) { identifier_class.new(invalid_checksum_id) }

      it 'returns false for #valid?' do
        expect(instance.valid?).to be(false)
      end

      it 'returns restored identifier string for #restore' do
        expect(instance.restore).to eq(restored_id)
      end

      it 'returns self for #restore!' do
        expect(instance.restore!).to be(instance)
        expect(instance.full_id).to eq(restored_id)
      end
    end

    context 'when identifier has invalid format' do
      let(:instance) { identifier_class.new(invalid_format_id) }

      it 'returns false for #valid?' do
        expect(instance.valid?).to be(false)
      end

      it 'raises error for #restore' do
        expect { instance.restore }.to raise_error(SecID::InvalidFormatError)
      end

      it 'raises error for #restore!' do
        expect { instance.restore! }.to raise_error(SecID::InvalidFormatError)
      end

      it 'raises error for #calculate_checksum' do
        expect { instance.calculate_checksum }.to raise_error(SecID::InvalidFormatError)
      end
    end
  end

  describe 'class methods' do
    describe '.valid?' do
      it 'returns true for valid identifier' do
        expect(identifier_class.valid?(valid_id)).to be(true)
      end

      it 'returns false for identifier without checksum' do
        expect(identifier_class.valid?(valid_id_without_check)).to be(false)
      end

      it 'returns false for identifier with invalid checksum' do
        expect(identifier_class.valid?(invalid_checksum_id)).to be(false)
      end

      it 'returns false for invalid format' do
        expect(identifier_class.valid?(invalid_format_id)).to be(false)
      end
    end

    describe '.restore' do
      it 'returns a String' do
        expect(identifier_class.restore(valid_id)).to be_a(String)
      end

      it 'restores valid identifier to itself' do
        expect(identifier_class.restore(valid_id)).to eq(restored_id)
      end

      it 'restores identifier without checksum' do
        expect(identifier_class.restore(valid_id_without_check)).to eq(restored_id)
      end

      it 'restores identifier with invalid checksum' do
        expect(identifier_class.restore(invalid_checksum_id)).to eq(restored_id)
      end

      it 'raises error for invalid format' do
        expect { identifier_class.restore(invalid_format_id) }.to raise_error(SecID::InvalidFormatError)
      end
    end

    describe '.restore!' do
      it 'returns an instance for valid identifier' do
        result = identifier_class.restore!(valid_id)
        expect(result).to be_a(identifier_class)
        expect(result.to_s).to eq(restored_id)
      end

      it 'returns an instance for identifier without checksum' do
        result = identifier_class.restore!(valid_id_without_check)
        expect(result).to be_a(identifier_class)
        expect(result.to_s).to eq(restored_id)
      end

      it 'returns an instance for identifier with invalid checksum' do
        result = identifier_class.restore!(invalid_checksum_id)
        expect(result).to be_a(identifier_class)
        expect(result.to_s).to eq(restored_id)
      end

      it 'raises error for invalid format' do
        expect { identifier_class.restore!(invalid_format_id) }.to raise_error(SecID::InvalidFormatError)
      end
    end

    describe '.checksum' do
      it 'returns the expected type' do
        expect(identifier_class.checksum(valid_id)).to be_a(expected_checksum_class)
      end

      it 'calculates checksum for valid identifier' do
        expect(identifier_class.checksum(valid_id)).to eq(expected_checksum)
      end

      it 'calculates checksum for identifier without checksum' do
        expect(identifier_class.checksum(valid_id_without_check)).to eq(expected_checksum)
      end

      it 'calculates checksum for identifier with invalid checksum' do
        expect(identifier_class.checksum(invalid_checksum_id)).to eq(expected_checksum)
      end

      it 'raises error for invalid format' do
        expect { identifier_class.checksum(invalid_format_id) }.to raise_error(SecID::InvalidFormatError)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
