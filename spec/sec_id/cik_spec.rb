# frozen_string_literal: true

RSpec.describe SecId::CIK do
  let(:cik) { described_class.new(cik_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Central Index Key',
                  id_length: 1..10,
                  has_check_digit: false,
                  has_normalization: true

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: '0001521365',
                  invalid_length_id: '00015213650000',
                  invalid_chars_id: 'ABCDEFG'

  it_behaves_like 'detects invalid format',
                  invalid_format_id: '0000000000'

  # Core normalization identifier behavior
  it_behaves_like 'a normalization identifier',
                  valid_id: '0001521365',
                  unnormalized_id: '1521365',
                  normalized_id: '0001521365',
                  invalid_id: '0000000000'

  context 'when CIK is valid' do
    let(:cik_number) { '0001521365' }

    it 'parses CIK correctly' do
      expect(cik.padding).to eq('000')
      expect(cik.identifier).to eq('1521365')
      expect(cik.full_number).to eq(cik_number)
    end

    describe '#normalize!' do
      it 'returns full CIK number' do
        expect(cik.normalize!).to eq(cik_number)
        expect(cik.full_number).to eq(cik_number)
      end
    end

    describe '#to_s' do
      it 'returns the full CIK number' do
        expect(cik.to_s).to eq(cik_number)
      end
    end
  end

  context 'when CIK number is missing leading zeros' do
    let(:cik_number) { '10624' }

    it 'parses CIK number correctly' do
      expect(cik.identifier).to eq(cik_number)
      expect(cik.full_number).to eq(cik_number)
    end

    describe '#normalize!' do
      it 'returns full CIK number and sets padding' do
        expect(cik.normalize!).to eq('0000010624')
        expect(cik.full_number).to eq('0000010624')
        expect(cik.padding).to eq('00000')
      end
    end

    describe '#to_s' do
      it 'returns the identifier before normalize' do
        expect(cik.to_s).to eq(cik_number)
      end

      it 'returns the full number after normalize' do
        cik.normalize!
        expect(cik.to_s).to eq('0000010624')
      end
    end
  end

  describe '.valid?' do
    context 'when CIK is malformed' do
      it 'returns false' do
        expect(described_class.valid?('X9')).to be(false)
        expect(described_class.valid?('0000000000')).to be(false)
        expect(described_class.valid?('01234567890')).to be(false)
      end
    end

    context 'when CIK is valid' do
      it 'returns true' do
        %w[0000000003 0000089562 0000010624 0002035979].each do |cik_number|
          expect(described_class.valid?(cik_number)).to be(true)
        end
      end
    end
  end

  describe '.normalize!' do
    context 'when CIK is malformed' do
      it 'raises an error' do
        expect { described_class.normalize!('X9') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.normalize!('0000000000') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.normalize!('09876543210') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when CIK is valid' do
      it 'normalizes padding and returns full CIK number' do
        expect(described_class.normalize!('3')).to eq('0000000003')
        expect(described_class.normalize!('0000000003')).to eq('0000000003')
        expect(described_class.normalize!('1072424')).to eq('0001072424')
        expect(described_class.normalize!('001072424')).to eq('0001072424')
        expect(described_class.normalize!('0001072424')).to eq('0001072424')
      end
    end
  end
end
