# frozen_string_literal: true

# Shared examples for the validation API (#errors, .validate).
# Tests that valid identifiers produce no errors and invalid ones produce expected error codes.
#
# @param valid_id [String] a valid identifier
# @param invalid_length_id [String] an identifier with wrong length
# @param invalid_chars_id [String] an identifier with invalid characters
RSpec.shared_examples 'a validatable identifier' do |params|
  let(:identifier_class) { described_class }

  describe '#to_s' do
    it 'returns a String' do
      expect(identifier_class.new(params[:valid_id]).to_s).to be_a(String)
    end
  end

  describe '#to_str' do
    it 'returns the same value as to_s' do
      instance = identifier_class.new(params[:valid_id])
      expect(instance.to_str).to eq(instance.to_s)
    end
  end

  describe '#errors' do
    context 'when identifier is valid' do
      it 'returns a valid ValidationResult' do
        result = identifier_class.new(params[:valid_id]).errors
        expect(result).to be_a(SecID::ValidationResult)
        expect(result.valid?).to be(true)
        expect(result.details).to be_empty
      end

      it 'memoizes the result' do
        instance = identifier_class.new(params[:valid_id])
        expect(instance.errors).to equal(instance.errors)
      end
    end

    context 'when identifier has invalid length' do
      it 'returns an invalid ValidationResult with :invalid_length' do
        result = identifier_class.new(params[:invalid_length_id]).errors
        expect(result.valid?).to be(false)
        expect(result.details.map { |d| d[:error] }).to include(:invalid_length)
        expect(result.details.first[:message]).to match(/Expected .+ characters, got \d+/)
      end

      it 'returns frozen error hashes' do
        result = identifier_class.new(params[:invalid_length_id]).errors
        expect(result.details.first).to be_frozen
      end
    end

    context 'when identifier has invalid characters' do
      it 'returns an invalid ValidationResult with :invalid_characters' do
        result = identifier_class.new(params[:invalid_chars_id]).errors
        expect(result.valid?).to be(false)
        expect(result.details.map { |d| d[:error] }).to include(:invalid_characters)
        expect(result.details.first[:message]).to match(/Contains invalid characters for/)
      end
    end

    context 'when input is nil, empty, or whitespace' do
      it 'returns invalid ValidationResult for nil' do
        expect(identifier_class.new(nil).errors.valid?).to be(false)
      end

      it 'returns invalid ValidationResult for empty string' do
        expect(identifier_class.new('').errors.valid?).to be(false)
      end

      it 'returns invalid ValidationResult for whitespace' do
        expect(identifier_class.new('   ').errors.valid?).to be(false)
      end
    end
  end

  describe '.validate' do
    it 'delegates to instance method' do
      result = identifier_class.validate(params[:valid_id])
      expect(result).to be_a(SecID::ValidationResult)
      expect(result.valid?).to be(true)
    end

    it 'returns invalid result for invalid input' do
      result = identifier_class.validate(params[:invalid_length_id])
      expect(result).to be_a(SecID::ValidationResult)
      expect(result.valid?).to be(false)
    end
  end
end

# Shared examples for check-digit identifiers that also detect :invalid_check_digit.
#
# @param valid_id [String] a valid identifier with correct check digit
# @param invalid_check_digit_id [String] an identifier with wrong check digit
RSpec.shared_examples 'detects invalid check digit' do |params|
  let(:identifier_class) { described_class }

  describe '#errors' do
    context 'when check digit is wrong' do
      it 'returns result with :invalid_check_digit and descriptive message' do
        result = identifier_class.new(params[:invalid_check_digit_id]).errors
        expect(result.valid?).to be(false)
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_check_digit])
        expect(result.details.first[:message]).to match(/invalid, expected/)
      end
    end

    context 'when check digit is correct' do
      it 'returns valid result' do
        result = identifier_class.new(params[:valid_id]).errors
        expect(result.valid?).to be(true)
      end
    end
  end
end

# Shared examples for the validate! API (#validate!, .validate!).
# Tests that valid identifiers return self and invalid ones raise appropriate exceptions.
#
# @param valid_id [String] a valid identifier
# @param invalid_length_id [String] an identifier with wrong length
# @param invalid_chars_id [String] an identifier with invalid characters
RSpec.shared_examples 'a validate! identifier' do |params|
  let(:identifier_class) { described_class }

  describe '#validate!' do
    context 'when identifier is valid' do
      it 'returns self' do
        instance = identifier_class.new(params[:valid_id])
        expect(instance.validate!).to equal(instance)
      end
    end

    context 'when identifier has invalid length' do
      it 'raises InvalidFormatError with message' do
        instance = identifier_class.new(params[:invalid_length_id])
        expect { instance.validate! }.to raise_error(SecID::InvalidFormatError, /Expected .+ characters, got \d+/)
      end
    end

    context 'when identifier has invalid characters' do
      it 'raises InvalidFormatError with message' do
        instance = identifier_class.new(params[:invalid_chars_id])
        expect { instance.validate! }.to raise_error(SecID::InvalidFormatError, /Contains invalid characters for/)
      end
    end
  end

  describe '.validate!' do
    it 'returns an instance of the identifier class when valid' do
      result = identifier_class.validate!(params[:valid_id])
      expect(result).to be_a(identifier_class)
      expect(result).to be_valid
    end

    it 'raises for invalid input' do
      expect { identifier_class.validate!(params[:invalid_length_id]) }.to raise_error(SecID::InvalidFormatError)
    end
  end
end

# Shared examples for check-digit identifiers that raise InvalidCheckDigitError via validate!.
#
# @param invalid_check_digit_id [String] an identifier with wrong check digit
RSpec.shared_examples 'validate! detects invalid check digit' do |params|
  describe '#validate!' do
    context 'when check digit is wrong' do
      it 'raises InvalidCheckDigitError with message' do
        instance = described_class.new(params[:invalid_check_digit_id])
        expect { instance.validate! }.to raise_error(SecID::InvalidCheckDigitError, /invalid, expected/)
      end
    end
  end
end

# Shared examples for identifiers where valid length + valid characters can still fail format.
#
# @param invalid_format_id [String] an identifier with valid length and chars but wrong structure
RSpec.shared_examples 'detects invalid format' do |params|
  describe '#errors' do
    context 'when format is invalid but length and characters are valid' do
      it 'returns :invalid_format with descriptive message' do
        result = described_class.new(params[:invalid_format_id]).errors
        expect(result.valid?).to be(false)
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_format])
        expect(result.details.first[:message]).to match(/Does not match .+ format/)
      end
    end
  end
end
