# frozen_string_literal: true

RSpec.describe SecId::ValidationResult do
  describe 'when valid (no errors)' do
    subject(:result) { described_class.new([]) }

    it 'is valid' do
      expect(result.valid?).to be(true)
    end

    it 'has empty errors' do
      expect(result.errors).to eq([])
    end

    it 'has empty error_codes' do
      expect(result.error_codes).to eq([])
    end

    it 'returns empty array from to_a' do
      expect(result.to_a).to eq([])
    end

    it 'is frozen' do
      expect(result).to be_frozen
    end

    it 'has frozen errors array' do
      expect(result.errors).to be_frozen
    end
  end

  describe 'when invalid (has errors)' do
    subject(:result) { described_class.new(errors) }

    let(:errors) do
      [
        { code: :invalid_length, message: 'Expected 12 characters, got 5' },
        { code: :invalid_characters, message: 'Contains invalid characters for ISIN' },
      ]
    end

    it 'is not valid' do
      expect(result.valid?).to be(false)
    end

    it 'returns errors' do
      expect(result.errors).to eq(errors)
    end

    it 'returns error codes' do
      expect(result.error_codes).to eq(%i[invalid_length invalid_characters])
    end

    it 'returns errors from to_a' do
      expect(result.to_a).to eq(errors)
    end

    it 'is frozen' do
      expect(result).to be_frozen
    end

    it 'has frozen errors array' do
      expect(result.errors).to be_frozen
    end
  end

  describe 'when single error' do
    subject(:result) { described_class.new(errors) }

    let(:errors) { [{ code: :invalid_check_digit, message: "Check digit '0' is invalid, expected '5'" }] }

    it 'is not valid' do
      expect(result.valid?).to be(false)
    end

    it 'returns single error code' do
      expect(result.error_codes).to eq([:invalid_check_digit])
    end
  end
end
