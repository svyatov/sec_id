# frozen_string_literal: true

# Shared examples for the validation API (#errors, .validate).
# Tests that valid identifiers produce no errors and invalid ones produce expected error codes.
#
# @param valid_id [String] a valid identifier
# @param invalid_length_id [String] an identifier with wrong length
# @param invalid_chars_id [String] an identifier with invalid characters
RSpec.shared_examples 'a validatable identifier' do |params|
  let(:identifier_class) { described_class }

  describe '#errors' do
    context 'when identifier is valid' do
      it 'returns a valid ValidationResult' do
        result = identifier_class.new(params[:valid_id]).errors
        expect(result).to be_a(SecId::ValidationResult)
        expect(result.valid?).to be(true)
        expect(result.details).to be_empty
      end
    end

    context 'when identifier has invalid length' do
      it 'returns an invalid ValidationResult with :invalid_length' do
        result = identifier_class.new(params[:invalid_length_id]).errors
        expect(result.valid?).to be(false)
        expect(result.details.map { |d| d[:error] }).to include(:invalid_length)
      end
    end

    context 'when identifier has invalid characters' do
      it 'returns an invalid ValidationResult with :invalid_characters' do
        result = identifier_class.new(params[:invalid_chars_id]).errors
        expect(result.valid?).to be(false)
        expect(result.details.map { |d| d[:error] }).to include(:invalid_characters)
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
