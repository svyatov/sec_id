# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers

# Shared examples for check-digit based identifiers (ISIN, CUSIP, SEDOL, FIGI, LEI, IBAN).
# Validates the core API: valid?, restore, restore!, check_digit.
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

      it 'returns a String for #restore' do
        result = instance.restore
        expect(result).to be_a(String)
        expect(result).to eq(valid_id)
      end

      it 'returns self for #restore!' do
        expect(instance.restore!).to equal(instance)
        expect(instance.full_id).to eq(valid_id)
      end

      it 'returns an Integer for #calculate_check_digit' do
        result = instance.calculate_check_digit
        expect(result).to be_a(Integer)
        expect(result).to eq(expected_check_digit)
      end
    end

    context 'when identifier is missing check-digit' do
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

      it 'does not mutate check_digit for #restore' do
        original_check_digit = instance.check_digit
        instance.restore
        expect(instance.check_digit).to eq(original_check_digit)
      end

      it 'returns self for #restore!' do
        expect(instance.restore!).to equal(instance)
        expect(instance.full_id).to eq(restored_id)
      end

      it 'sets check_digit for #restore!' do
        instance.restore!
        expect(instance.check_digit).to eq(expected_check_digit)
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
        expect { instance.restore }.to raise_error(SecId::InvalidFormatError)
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

    describe '.restore' do
      it 'returns a String' do
        expect(identifier_class.restore(valid_id)).to be_a(String)
      end

      it 'restores valid identifier to itself' do
        expect(identifier_class.restore(valid_id)).to eq(restored_id)
      end

      it 'restores identifier without check-digit' do
        expect(identifier_class.restore(valid_id_without_check)).to eq(restored_id)
      end

      it 'restores identifier with invalid check-digit' do
        expect(identifier_class.restore(invalid_check_digit_id)).to eq(restored_id)
      end

      it 'raises error for invalid format' do
        expect { identifier_class.restore(invalid_format_id) }.to raise_error(SecId::InvalidFormatError)
      end
    end

    describe '.restore!' do
      it 'returns an instance for valid identifier' do
        result = identifier_class.restore!(valid_id)
        expect(result).to be_a(identifier_class)
        expect(result.to_s).to eq(restored_id)
      end

      it 'returns an instance for identifier without check-digit' do
        result = identifier_class.restore!(valid_id_without_check)
        expect(result).to be_a(identifier_class)
        expect(result.to_s).to eq(restored_id)
      end

      it 'returns an instance for identifier with invalid check-digit' do
        result = identifier_class.restore!(invalid_check_digit_id)
        expect(result).to be_a(identifier_class)
        expect(result.to_s).to eq(restored_id)
      end

      it 'raises error for invalid format' do
        expect { identifier_class.restore!(invalid_format_id) }.to raise_error(SecId::InvalidFormatError)
      end
    end

    describe '.check_digit' do
      it 'returns an Integer' do
        expect(identifier_class.check_digit(valid_id)).to be_a(Integer)
      end

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
