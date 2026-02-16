# frozen_string_literal: true

RSpec.describe SecId::LEI do
  let(:lei) { described_class.new(lei_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Legal Entity Identifier',
                  id_length: 20,
                  has_check_digit: true

  it_behaves_like 'a normalizable identifier',
                  valid_id: '529900T8BM49AURSDO55',
                  dirty_id: '5299 00t8 bm49 aurs do55',
                  invalid_id: 'INVALID'

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: '5493006MHB84DD0ZWV18',
                  invalid_length_id: '5493',
                  invalid_chars_id: '5493006MHB84DD0ZWV!!'

  it_behaves_like 'a validate! identifier',
                  valid_id: '5493006MHB84DD0ZWV18',
                  invalid_length_id: '5493',
                  invalid_chars_id: '5493006MHB84DD0ZWV!!'

  it_behaves_like 'detects invalid check digit',
                  valid_id: '5493006MHB84DD0ZWV18',
                  invalid_check_digit_id: '5493006MHB84DD0ZWV99'

  it_behaves_like 'validate! detects invalid check digit',
                  invalid_check_digit_id: '5493006MHB84DD0ZWV99'

  # Core check-digit identifier behavior
  it_behaves_like 'a check-digit identifier',
                  valid_id: '5493006MHB84DD0ZWV18',
                  valid_id_without_check: '5493006MHB84DD0ZWV',
                  restored_id: '5493006MHB84DD0ZWV18',
                  invalid_format_id: 'INVALID',
                  invalid_check_digit_id: '5493006MHB84DD0ZWV99',
                  expected_check_digit: 18

  context 'when LEI is valid' do
    let(:lei_number) { '5493006MHB84DD0ZWV18' }

    it 'parses LEI correctly' do
      expect(lei.identifier).to eq('5493006MHB84DD0ZWV')
      expect(lei.lou_id).to eq('5493')
      expect(lei.reserved).to eq('00')
      expect(lei.entity_id).to eq('6MHB84DD0ZWV')
      expect(lei.check_digit).to eq(18)
    end

    describe '#to_s' do
      it 'returns full LEI' do
        expect(lei.to_s).to eq(lei_number)
      end
    end
  end

  context 'when LEI is missing check-digit' do
    let(:lei_number) { '5493006MHB84DD0ZWV' }

    it 'parses LEI correctly' do
      expect(lei.identifier).to eq(lei_number)
      expect(lei.lou_id).to eq('5493')
      expect(lei.reserved).to eq('00')
      expect(lei.entity_id).to eq('6MHB84DD0ZWV')
      expect(lei.check_digit).to be_nil
    end
  end

  context 'when LEI has all-letter LOU identifier' do
    let(:lei_number) { 'HWUPKR0MPOU8FGXBT394' }

    it 'parses LEI correctly' do
      expect(lei.identifier).to eq('HWUPKR0MPOU8FGXBT3')
      expect(lei.lou_id).to eq('HWUP')
      expect(lei.reserved).to eq('KR')
      expect(lei.entity_id).to eq('0MPOU8FGXBT3')
      expect(lei.check_digit).to eq(94)
    end

    describe '#valid?' do
      it 'returns true' do
        expect(lei.valid?).to be(true)
      end
    end

    describe '#to_s' do
      it 'returns full LEI' do
        expect(lei.to_s).to eq(lei_number)
      end
    end
  end

  context 'when LEI format is invalid' do
    let(:lei_number) { 'INVALID' }

    it 'parses LEI as nil' do
      expect(lei.identifier).to be_nil
      expect(lei.lou_id).to be_nil
      expect(lei.reserved).to be_nil
      expect(lei.entity_id).to be_nil
      expect(lei.check_digit).to be_nil
    end
  end

  context 'when LEI contains lowercase letters' do
    let(:lei_number) { '5493006mhb84dd0zwv18' }

    it 'normalizes to uppercase and parses correctly' do
      expect(lei.identifier).to eq('5493006MHB84DD0ZWV')
      expect(lei.valid?).to be(true)
    end
  end

  describe '.valid?' do
    context 'when LEI is valid' do
      it 'returns true for real-world LEI examples' do
        expect(described_class.valid?('5493006MHB84DD0ZWV18')).to be(true)
        expect(described_class.valid?('529900T8BM49AURSDO55')).to be(true)
        expect(described_class.valid?('HWUPKR0MPOU8FGXBT394')).to be(true)
        expect(described_class.valid?('7ZW8QJWVPR4P1J1KQY45')).to be(true)
        expect(described_class.valid?('549300TRUWO2CD2G5692')).to be(true)
      end
    end
  end

  describe '.restore!' do
    context 'when LEI format is valid' do
      it 'restores check-digit for various LEIs' do
        expect(described_class.restore!('5493006MHB84DD0ZWV')).to eq('5493006MHB84DD0ZWV18')
        expect(described_class.restore!('5493006MHB84DD0ZWV99')).to eq('5493006MHB84DD0ZWV18')
        expect(described_class.restore!('529900T8BM49AURSDO')).to eq('529900T8BM49AURSDO55')
        expect(described_class.restore!('HWUPKR0MPOU8FGXBT3')).to eq('HWUPKR0MPOU8FGXBT394')
      end
    end
  end

  describe '.check_digit' do
    context 'when LEI format is valid' do
      it 'calculates check-digit for various LEIs' do
        expect(described_class.check_digit('5493006MHB84DD0ZWV')).to eq(18)
        expect(described_class.check_digit('5493006MHB84DD0ZWV18')).to eq(18)
        expect(described_class.check_digit('529900T8BM49AURSDO')).to eq(55)
        expect(described_class.check_digit('HWUPKR0MPOU8FGXBT3')).to eq(94)
        expect(described_class.check_digit('7ZW8QJWVPR4P1J1KQY')).to eq(45)
      end
    end
  end
end
