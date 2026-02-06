# frozen_string_literal: true

RSpec.describe SecId::WKN do
  let(:wkn) { described_class.new(wkn_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Wertpapierkennnummer',
                  id_length: 6,
                  has_check_digit: false,
                  has_normalization: false

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: '514000',
                  invalid_length_id: '51',
                  invalid_chars_id: '514-00'

  context 'when WKN is valid' do
    let(:wkn_number) { '514000' }

    it 'parses WKN correctly' do
      expect(wkn.identifier).to eq('514000')
    end

    it 'returns the full number' do
      expect(wkn.full_number).to eq('514000')
    end

    describe '#to_s' do
      it 'returns the identifier' do
        expect(wkn.to_s).to eq('514000')
      end
    end
  end

  context 'when WKN is alphanumeric' do
    let(:wkn_number) { 'CBK100' }

    it 'parses WKN correctly' do
      expect(wkn.identifier).to eq('CBK100')
    end
  end

  context 'when WKN is lowercase' do
    let(:wkn_number) { 'cbk100' }

    it 'normalizes to uppercase' do
      expect(wkn.identifier).to eq('CBK100')
    end
  end

  context 'when WKN is mixed case' do
    let(:wkn_number) { 'Cbk100' }

    it 'normalizes to uppercase' do
      expect(wkn.identifier).to eq('CBK100')
    end
  end

  context 'when WKN is all zeros' do
    let(:wkn_number) { '000000' }

    it 'parses correctly and is valid' do
      expect(wkn.identifier).to eq('000000')
      expect(wkn.valid?).to be(true)
    end
  end

  context 'when WKN is all nines' do
    let(:wkn_number) { '999999' }

    it 'parses correctly and is valid' do
      expect(wkn.identifier).to eq('999999')
      expect(wkn.valid?).to be(true)
    end
  end

  describe '.valid?' do
    context 'when WKN is valid' do
      it 'returns true for various valid WKNs' do
        %w[
          514000 CBK100 840400 519000 716460 723610
          A1EWWW BASF11 BAY001 DTR0CK ENAG99 A0D9PT
        ].each do |wkn_number|
          expect(described_class.valid?(wkn_number)).to be(true)
        end
      end
    end

    context 'when WKN is invalid' do
      it 'returns false for wrong length' do
        expect(described_class.valid?('12345')).to be(false)
        expect(described_class.valid?('1234567')).to be(false)
      end

      it 'returns false for forbidden letters I and O' do
        expect(described_class.valid?('ABICD1')).to be(false)
        expect(described_class.valid?('ABOCD1')).to be(false)
      end

      it 'returns false for invalid characters' do
        expect(described_class.valid?('514-00')).to be(false)
        expect(described_class.valid?('51400@')).to be(false)
      end

      it 'returns false for internal whitespace' do
        expect(described_class.valid?('514 00')).to be(false)
      end

      it 'allows leading/trailing whitespace (stripped by parser)' do
        expect(described_class.valid?(' 514000')).to be(true)
        expect(described_class.valid?('514000 ')).to be(true)
        expect(described_class.valid?(' 514000 ')).to be(true)
      end
    end
  end

  describe '#to_isin' do
    context 'when WKN is valid' do
      let(:wkn_number) { '716460' }

      it 'returns an ISIN instance for default DE country code' do
        result = wkn.to_isin
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_number).to eq('DE0007164600')
        expect(result.country_code).to eq('DE')
      end

      it 'returns an ISIN instance for explicit DE country code' do
        result = wkn.to_isin('DE')
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_number).to eq('DE0007164600')
      end

      it 'raises InvalidFormatError for invalid country code' do
        expect { wkn.to_isin('US') }.to raise_error(
          SecId::InvalidFormatError, "'US' is not a valid WKN country code!"
        )
      end
    end

    context 'when WKN is alphanumeric' do
      let(:wkn_number) { 'CBK100' }

      it 'returns valid ISIN' do
        result = wkn.to_isin
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_number).to eq('DE000CBK1001')
      end
    end

    context 'when WKN format is invalid' do
      let(:wkn_number) { '12345' }

      it 'raises InvalidFormatError' do
        expect { wkn.to_isin }.to raise_error(
          SecId::InvalidFormatError, "WKN '12345' is invalid!"
        )
      end
    end

    context 'when round-trip conversion' do
      let(:wkn_number) { '716460' }

      it 'preserves WKN value' do
        isin = wkn.to_isin
        wkn2 = isin.to_wkn
        expect(wkn.full_number).to eq(wkn2.full_number)
      end
    end
  end
end
