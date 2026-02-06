# frozen_string_literal: true

# Shared examples for the validation API (#validate, #validation_errors).
# Tests that valid identifiers produce no errors and invalid ones produce expected error codes.
#
# @param valid_id [String] a valid identifier
# @param invalid_length_id [String] an identifier with wrong length
# @param invalid_chars_id [String] an identifier with invalid characters
RSpec.shared_examples 'a validatable identifier' do |params|
  let(:identifier_class) { described_class }

  describe '#validate' do
    context 'when identifier is valid' do
      it 'returns a valid ValidationResult' do
        result = identifier_class.new(params[:valid_id]).validate
        expect(result).to be_a(SecId::ValidationResult)
        expect(result.valid?).to be(true)
        expect(result.errors).to be_empty
      end
    end

    context 'when identifier has invalid length' do
      it 'returns an invalid ValidationResult with :invalid_length' do
        result = identifier_class.new(params[:invalid_length_id]).validate
        expect(result.valid?).to be(false)
        expect(result.error_codes).to include(:invalid_length)
      end
    end

    context 'when identifier has invalid characters' do
      it 'returns an invalid ValidationResult with :invalid_characters' do
        result = identifier_class.new(params[:invalid_chars_id]).validate
        expect(result.valid?).to be(false)
        expect(result.error_codes).to include(:invalid_characters)
      end
    end
  end

  describe '#validation_errors' do
    context 'when identifier is valid' do
      it 'returns an empty array' do
        expect(identifier_class.new(params[:valid_id]).validation_errors).to eq([])
      end
    end

    context 'when identifier has invalid length' do
      it 'returns [:invalid_length]' do
        expect(identifier_class.new(params[:invalid_length_id]).validation_errors).to include(:invalid_length)
      end
    end

    context 'when identifier has invalid characters' do
      it 'returns [:invalid_characters]' do
        expect(identifier_class.new(params[:invalid_chars_id]).validation_errors).to include(:invalid_characters)
      end
    end
  end

  describe '.validate' do
    it 'delegates to instance method' do
      result = identifier_class.validate(params[:valid_id])
      expect(result).to be_a(SecId::ValidationResult)
      expect(result.valid?).to be(true)
    end
  end

  describe '.validation_errors' do
    it 'delegates to instance method' do
      expect(identifier_class.validation_errors(params[:valid_id])).to eq([])
    end
  end
end

# Shared examples for check-digit identifiers that also detect :invalid_check_digit.
#
# @param valid_id [String] a valid identifier with correct check digit
# @param invalid_check_digit_id [String] an identifier with wrong check digit
RSpec.shared_examples 'detects invalid check digit' do |params|
  let(:identifier_class) { described_class }

  describe '#validation_errors' do
    context 'when check digit is wrong' do
      it 'returns [:invalid_check_digit]' do
        errors = identifier_class.new(params[:invalid_check_digit_id]).validation_errors
        expect(errors).to eq([:invalid_check_digit])
      end
    end

    context 'when check digit is correct' do
      it 'returns empty array' do
        errors = identifier_class.new(params[:valid_id]).validation_errors
        expect(errors).to eq([])
      end
    end
  end

  describe '#validate' do
    context 'when check digit is wrong' do
      it 'returns result with :invalid_check_digit and descriptive message' do
        result = identifier_class.new(params[:invalid_check_digit_id]).validate
        expect(result.valid?).to be(false)
        expect(result.error_codes).to eq([:invalid_check_digit])
        expect(result.errors.first[:message]).to match(/invalid, expected/)
      end
    end
  end
end
