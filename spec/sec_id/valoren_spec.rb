# frozen_string_literal: true

RSpec.describe SecID::Valoren do
  let(:valoren) { described_class.new(valoren_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Valoren Number',
                  id_length: 5..9,
                  has_check_digit: false

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: '3886335',
                  invalid_length_id: '12',
                  invalid_chars_id: 'ABCDE'

  it_behaves_like 'a validate! identifier',
                  valid_id: '3886335',
                  invalid_length_id: '12',
                  invalid_chars_id: 'ABCDE'

  # Normalization
  it_behaves_like 'a formattable identifier',
                  valid_id: '003886335',
                  dirty_id: '  3886335  ',
                  invalid_id: '0000'

  it_behaves_like 'a normalizable identifier',
                  valid_id: '003886335',
                  canonical_id: '003886335',
                  dirty_id: '  3886335  ',
                  invalid_id: '0000'

  # Serialization
  it_behaves_like 'a hashable identifier',
                  valid_id: '003886335',
                  invalid_id: '0000',
                  expected_type: :valoren,
                  expected_components: {}

  context 'when Valoren is valid' do
    let(:valoren_number) { '003886335' }

    it 'parses Valoren correctly' do
      expect(valoren.padding).to eq('00')
      expect(valoren.identifier).to eq('3886335')
      expect(valoren.full_id).to eq(valoren_number)
    end

    describe '#normalize!' do
      it 'updates full_id and returns self' do
        expect(valoren.normalize!).to be(valoren)
        expect(valoren.full_id).to eq(valoren_number)
      end
    end

    describe '#to_s' do
      it 'returns the full Valoren number' do
        expect(valoren.to_s).to eq(valoren_number)
      end
    end
  end

  context 'when Valoren is missing leading zeros' do
    let(:valoren_number) { '3886335' }

    it 'parses Valoren correctly' do
      expect(valoren.identifier).to eq(valoren_number)
      expect(valoren.full_id).to eq(valoren_number)
    end

    describe '#normalize!' do
      it 'returns self and sets padding' do
        expect(valoren.normalize!).to be(valoren)
        expect(valoren.full_id).to eq('003886335')
        expect(valoren.padding).to eq('00')
      end
    end

    describe '#to_s' do
      it 'returns the identifier before normalize' do
        expect(valoren.to_s).to eq(valoren_number)
      end

      it 'returns the full number after normalize' do
        valoren.normalize!
        expect(valoren.to_s).to eq('003886335')
      end
    end
  end

  describe '.valid?' do
    context 'when Valoren is malformed' do
      it 'returns false' do
        expect(described_class.valid?('X9')).to be(false)
        expect(described_class.valid?('0000')).to be(false)
        expect(described_class.valid?('0123456789')).to be(false)
      end

      it 'returns false for all-zeros (must start with 1-9)' do
        expect(described_class.valid?('000000000')).to be(false)
        expect(described_class.valid?('00000')).to be(false)
      end

      it 'returns false for identifiers with only leading zeros (no significant digits)' do
        # "00001" is only 5 chars but identifier portion is "1" which is too short
        expect(described_class.valid?('00001')).to be(false)
      end
    end

    context 'when Valoren is valid' do
      it 'returns true for various valid Valorens' do
        %w[
          3886335 003886335
          24476758 024476758
          35514757 035514757
          97429325 097429325
        ].each do |valoren_number|
          expect(described_class.valid?(valoren_number)).to be(true)
        end
      end

      it 'returns true for minimum 5-digit Valoren' do
        expect(described_class.valid?('12345')).to be(true)
      end

      it 'returns true for 5-digit Valoren with leading zeros (9 digits total)' do
        expect(described_class.valid?('000012345')).to be(true)
      end
    end
  end

  describe '.normalize' do
    context 'when Valoren is malformed' do
      it 'raises an error' do
        expect { described_class.normalize('X9') }.to raise_error(SecID::InvalidFormatError)
        expect { described_class.normalize('0000') }.to raise_error(SecID::InvalidFormatError)
        expect { described_class.normalize('0123456789') }.to raise_error(SecID::InvalidFormatError)
      end
    end

    context 'when Valoren is valid' do
      it 'normalizes padding and returns full Valoren number' do
        expect(described_class.normalize('3886335')).to eq('003886335')
        expect(described_class.normalize('003886335')).to eq('003886335')
        expect(described_class.normalize('24476758')).to eq('024476758')
        expect(described_class.normalize('35514757')).to eq('035514757')
        expect(described_class.normalize('97429325')).to eq('097429325')
      end
    end
  end

  describe '#to_isin' do
    context 'when Valoren is valid' do
      let(:valoren_number) { '1222171' }

      it 'returns an ISIN instance for default CH country code' do
        result = valoren.to_isin
        expect(result).to be_a(SecID::ISIN)
        expect(result.full_id).to eq('CH0012221716')
        expect(result.country_code).to eq('CH')
      end

      it 'returns an ISIN instance for LI country code' do
        result = valoren.to_isin('LI')
        expect(result).to be_a(SecID::ISIN)
        expect(result.full_id).to eq('LI0012221714')
        expect(result.country_code).to eq('LI')
      end

      it 'raises InvalidFormatError for invalid country code' do
        expect { valoren.to_isin('US') }.to raise_error(
          SecID::InvalidFormatError, "'US' is not a valid Valoren country code!"
        )
      end
    end

    context 'when Valoren is missing leading zeros' do
      let(:valoren_number) { '3886335' }

      it 'normalizes and returns valid ISIN' do
        result = valoren.to_isin
        expect(result).to be_a(SecID::ISIN)
        expect(result.full_id).to eq('CH0038863350')
        expect(valoren.full_id).to eq('3886335')
      end
    end

    context 'when round-trip conversion' do
      let(:valoren_number) { '1222171' }

      it 'preserves Valoren value' do
        isin = valoren.to_isin
        valoren2 = isin.to_valoren
        expect(valoren.identifier).to eq(valoren2.identifier)
      end
    end
  end

  describe '#to_pretty_s' do
    it 'formats with thousands grouping' do
      expect(described_class.new('3886335').to_pretty_s).to eq('3 886 335')
    end

    it 'formats without leading zeros' do
      expect(described_class.new('003886335').to_pretty_s).to eq('3 886 335')
    end

    it 'formats 5-digit valoren' do
      expect(described_class.new('12345').to_pretty_s).to eq('12 345')
    end
  end
end
