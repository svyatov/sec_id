# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers

# Shared examples for check-digit based identifiers (ISIN, CUSIP, SEDOL, FIGI, LEI, IBAN).
# Validates the core API: valid?, restore!, check_digit.
#
# @param valid_id [String] a valid identifier with correct check-digit
# @param valid_id_without_check [String] a valid identifier without check-digit (for restoration)
# @param restored_id [String] the expected full identifier after restoration
# @param invalid_format_id [String] an identifier with invalid format
# @param invalid_check_digit_id [String] an identifier with wrong check-digit
# @param expected_check_digit [Integer] the expected check-digit value
RSpec.shared_examples 'a check-digit identifier' do |params|
  let(:identifier_class) { described_class }
  let(:valid_id) { params[:valid_id] }
  let(:valid_id_without_check) { params[:valid_id_without_check] }
  let(:restored_id) { params[:restored_id] }
  let(:invalid_format_id) { params[:invalid_format_id] }
  let(:invalid_check_digit_id) { params[:invalid_check_digit_id] }
  let(:expected_check_digit) { params[:expected_check_digit] }

  describe 'instance methods' do
    context 'when identifier is valid with correct check-digit' do
      let(:instance) { identifier_class.new(valid_id) }

      it 'returns true for #valid?' do
        expect(instance.valid?).to be(true)
      end

      it 'restores to itself with #restore!' do
        expect(instance.restore!).to eq(valid_id)
        expect(instance.full_number).to eq(valid_id)
      end

      it 'calculates correct check-digit' do
        expect(instance.calculate_check_digit).to eq(expected_check_digit)
      end
    end

    context 'when identifier is missing check-digit' do
      let(:instance) { identifier_class.new(valid_id_without_check) }

      it 'returns false for #valid?' do
        expect(instance.valid?).to be(false)
      end

      it 'restores check-digit with #restore!' do
        expect(instance.restore!).to eq(restored_id)
        expect(instance.full_number).to eq(restored_id)
      end

      it 'calculates correct check-digit' do
        expect(instance.calculate_check_digit).to eq(expected_check_digit)
      end
    end

    context 'when identifier has invalid check-digit' do
      let(:instance) { identifier_class.new(invalid_check_digit_id) }

      it 'returns false for #valid?' do
        expect(instance.valid?).to be(false)
      end

      it 'restores to correct check-digit with #restore!' do
        expect(instance.restore!).to eq(restored_id)
        expect(instance.full_number).to eq(restored_id)
      end
    end

    context 'when identifier has invalid format' do
      let(:instance) { identifier_class.new(invalid_format_id) }

      it 'returns false for #valid?' do
        expect(instance.valid?).to be(false)
      end

      it 'raises error for #restore!' do
        expect { instance.restore! }.to raise_error(SecId::InvalidFormatError)
      end

      it 'raises error for #calculate_check_digit' do
        expect { instance.calculate_check_digit }.to raise_error(SecId::InvalidFormatError)
      end
    end
  end

  describe 'class methods' do
    describe '.valid?' do
      it 'returns true for valid identifier' do
        expect(identifier_class.valid?(valid_id)).to be(true)
      end

      it 'returns false for identifier without check-digit' do
        expect(identifier_class.valid?(valid_id_without_check)).to be(false)
      end

      it 'returns false for identifier with invalid check-digit' do
        expect(identifier_class.valid?(invalid_check_digit_id)).to be(false)
      end

      it 'returns false for invalid format' do
        expect(identifier_class.valid?(invalid_format_id)).to be(false)
      end
    end

    describe '.restore!' do
      it 'restores valid identifier to itself' do
        expect(identifier_class.restore!(valid_id)).to eq(restored_id)
      end

      it 'restores identifier without check-digit' do
        expect(identifier_class.restore!(valid_id_without_check)).to eq(restored_id)
      end

      it 'restores identifier with invalid check-digit' do
        expect(identifier_class.restore!(invalid_check_digit_id)).to eq(restored_id)
      end

      it 'raises error for invalid format' do
        expect { identifier_class.restore!(invalid_format_id) }.to raise_error(SecId::InvalidFormatError)
      end
    end

    describe '.check_digit' do
      it 'calculates check-digit for valid identifier' do
        expect(identifier_class.check_digit(valid_id)).to eq(expected_check_digit)
      end

      it 'calculates check-digit for identifier without check-digit' do
        expect(identifier_class.check_digit(valid_id_without_check)).to eq(expected_check_digit)
      end

      it 'calculates check-digit for identifier with invalid check-digit' do
        expect(identifier_class.check_digit(invalid_check_digit_id)).to eq(expected_check_digit)
      end

      it 'raises error for invalid format' do
        expect { identifier_class.check_digit(invalid_format_id) }.to raise_error(SecId::InvalidFormatError)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
