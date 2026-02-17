# frozen_string_literal: true

RSpec.describe SecID::ValidationResult do
  describe 'when valid (no errors)' do
    subject(:result) { described_class.new([]) }

    it 'is valid' do
      expect(result.valid?).to be(true)
    end

    it 'has empty details' do
      expect(result.details).to eq([])
    end

    it 'has empty messages' do
      expect(result.messages).to eq([])
    end

    it 'is not any' do
      expect(result.any?).to be(false)
    end

    it 'is empty' do
      expect(result.empty?).to be(true)
    end

    it 'has size 0' do
      expect(result.size).to eq(0)
    end

    it 'returns empty array from to_a' do
      expect(result.to_a).to eq([])
    end

    it 'is frozen' do
      expect(result).to be_frozen
    end

    it 'has frozen details array' do
      expect(result.details).to be_frozen
    end
  end

  describe 'when invalid (has errors)' do
    subject(:result) { described_class.new(errors) }

    let(:errors) do
      [
        { error: :invalid_length, message: 'Expected 12 characters, got 5' },
        { error: :invalid_characters, message: 'Contains invalid characters for ISIN' },
      ]
    end

    it 'is not valid' do
      expect(result.valid?).to be(false)
    end

    it 'returns details' do
      expect(result.details).to eq(errors)
    end

    it 'returns messages' do
      expect(result.messages).to eq(['Expected 12 characters, got 5', 'Contains invalid characters for ISIN'])
    end

    it 'is any' do
      expect(result.any?).to be(true)
    end

    it 'is not empty' do
      expect(result.empty?).to be(false)
    end

    it 'has size 2' do
      expect(result.size).to eq(2)
    end

    it 'returns messages from to_a' do
      expect(result.to_a).to eq(result.messages)
    end

    it 'returns strings from to_a, not hashes' do
      expect(result.to_a).to all(be_a(String))
      expect(result.to_a).not_to eq(result.details)
    end

    it 'is frozen' do
      expect(result).to be_frozen
    end

    it 'has frozen details array' do
      expect(result.details).to be_frozen
    end
  end

  describe 'when single error' do
    subject(:result) { described_class.new(errors) }

    let(:errors) { [{ error: :invalid_check_digit, message: "Check digit '0' is invalid, expected '5'" }] }

    it 'is not valid' do
      expect(result.valid?).to be(false)
    end

    it 'returns single detail' do
      expect(result.details.first[:error]).to eq(:invalid_check_digit)
    end

    it 'has size 1' do
      expect(result.size).to eq(1)
    end
  end
end
