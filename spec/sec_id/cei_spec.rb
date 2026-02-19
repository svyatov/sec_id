# frozen_string_literal: true

RSpec.describe SecID::CEI do
  let(:cei) { described_class.new(cei_number) }

  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'CUSIP Entity Identifier',
                  id_length: 10,
                  has_check_digit: true

  it_behaves_like 'a normalizable identifier',
                  valid_id: 'A0BCDEFGH1',
                  dirty_id: 'a0-bcde-fgh1',
                  invalid_id: 'INVALID'

  it_behaves_like 'a formattable identifier',
                  valid_id: 'A0BCDEFGH1',
                  dirty_id: 'a0-bcde-fgh1',
                  invalid_id: 'INVALID'

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'A0BCDEFGH1',
                  invalid_length_id: 'A0',
                  invalid_chars_id: 'A0BCDEFG!1'

  it_behaves_like 'a validate! identifier',
                  valid_id: 'A0BCDEFGH1',
                  invalid_length_id: 'A0',
                  invalid_chars_id: 'A0BCDEFG!1'

  it_behaves_like 'detects invalid check digit',
                  valid_id: 'A0BCDEFGH1',
                  invalid_check_digit_id: 'A0BCDEFGH0'

  it_behaves_like 'validate! detects invalid check digit',
                  invalid_check_digit_id: 'A0BCDEFGH0'

  # Serialization
  it_behaves_like 'a hashable identifier',
                  valid_id: 'A0BCDEFGH1',
                  invalid_id: 'INVALID',
                  expected_type: :cei,
                  expected_components: { prefix: 'A', numeric: '0', entity_id: 'BCDEFGH', check_digit: 1 }

  it_behaves_like 'a check-digit identifier',
                  valid_id: 'A0BCDEFGH1',
                  valid_id_without_check: 'A0BCDEFGH',
                  restored_id: 'A0BCDEFGH1',
                  invalid_format_id: 'INVALID',
                  invalid_check_digit_id: 'A0BCDEFGH0',
                  expected_check_digit: 1

  context 'when CEI is valid' do
    let(:cei_number) { 'A0BCDEFGH1' }

    it 'parses CEI correctly' do
      expect(cei.identifier).to eq('A0BCDEFGH')
      expect(cei.prefix).to eq('A')
      expect(cei.numeric).to eq('0')
      expect(cei.entity_id).to eq('BCDEFGH')
      expect(cei.check_digit).to eq(1)
    end
  end

  context 'when CEI number is missing check-digit' do
    let(:cei_number) { 'A0BCDEFGH' }

    it 'parses CEI number correctly' do
      expect(cei.identifier).to eq(cei_number)
      expect(cei.prefix).to eq('A')
      expect(cei.numeric).to eq('0')
      expect(cei.entity_id).to eq('BCDEFGH')
      expect(cei.check_digit).to be_nil
    end
  end

  describe '.valid?' do
    it 'returns true for valid CEIs' do
      %w[A0BCDEFGH1 A0A0A0A0A0 Z9ZZZZZZZ2].each do |cei_number|
        expect(described_class.valid?(cei_number)).to be(true)
      end
    end
  end

  describe '.restore!' do
    it 'restores check-digit for various CEIs' do
      expect(described_class.restore!('A0BCDEFGH').to_s).to eq('A0BCDEFGH1')
      expect(described_class.restore!('A0A0A0A0A').to_s).to eq('A0A0A0A0A0')
      expect(described_class.restore!('Z9ZZZZZZZ').to_s).to eq('Z9ZZZZZZZ2')
    end
  end

  describe '.check_digit' do
    it 'calculates check-digit for various CEIs' do
      expect(described_class.check_digit('A0BCDEFGH')).to eq(1)
      expect(described_class.check_digit('A0A0A0A0A')).to eq(0)
      expect(described_class.check_digit('Z9ZZZZZZZ')).to eq(2)
    end
  end
end
