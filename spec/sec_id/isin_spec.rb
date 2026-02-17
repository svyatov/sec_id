# frozen_string_literal: true

RSpec.describe SecID::ISIN do
  let(:isin) { described_class.new(isin_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'International Securities Identification Number',
                  id_length: 12,
                  has_check_digit: true

  it_behaves_like 'a normalizable identifier',
                  valid_id: 'US5949181045',
                  dirty_id: 'us-5949-1810-45',
                  invalid_id: 'INVALID'

  it_behaves_like 'a formattable identifier',
                  valid_id: 'US5949181045',
                  dirty_id: 'us-5949-1810-45',
                  invalid_id: 'INVALID'

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'US5949181045',
                  invalid_length_id: 'US',
                  invalid_chars_id: 'US59491810-5'

  it_behaves_like 'a validate! identifier',
                  valid_id: 'US5949181045',
                  invalid_length_id: 'US',
                  invalid_chars_id: 'US59491810-5'

  it_behaves_like 'detects invalid check digit',
                  valid_id: 'US5949181045',
                  invalid_check_digit_id: 'IE00B296YR70'

  it_behaves_like 'validate! detects invalid check digit',
                  invalid_check_digit_id: 'IE00B296YR70'

  # Core check-digit identifier behavior
  it_behaves_like 'a check-digit identifier',
                  valid_id: 'IE00B296YR77',
                  valid_id_without_check: 'IE00B296YR7',
                  restored_id: 'IE00B296YR77',
                  invalid_format_id: '00B296YR77',
                  invalid_check_digit_id: 'IE00B296YR70',
                  expected_check_digit: 7

  context 'when ISIN is valid' do
    let(:isin_number) { 'IE00B296YR77' }

    it 'parses ISIN correctly' do
      expect(isin.identifier).to eq('IE00B296YR7')
      expect(isin.country_code).to eq('IE')
      expect(isin.nsin).to eq('00B296YR7')
      expect(isin.check_digit).to eq(7)
    end
  end

  context 'when ISIN is missing country code' do
    let(:isin_number) { '00B296YR77' }

    it 'parses ISIN correctly' do
      expect(isin.identifier).to be_nil
      expect(isin.country_code).to be_nil
      expect(isin.nsin).to be_nil
      expect(isin.check_digit).to be_nil
    end
  end

  context 'when ISIN number is missing check-digit' do
    let(:isin_number) { 'IE00B296YR7' }

    it 'parses ISIN number correctly' do
      expect(isin.identifier).to eq(isin_number)
      expect(isin.country_code).to eq('IE')
      expect(isin.nsin).to eq('00B296YR7')
      expect(isin.check_digit).to be_nil
    end
  end

  describe '#to_cusip' do
    context 'when CGS country code' do
      let(:isin_number) { 'VI02153X1080' }

      it 'returns a CUSIP' do
        expect(isin.cgs?).to be(true)
        expect(isin.to_cusip).to be_a(SecID::CUSIP)
      end
    end

    context 'when non-CGS country code' do
      let(:isin_number) { 'IE00B296YR77' }

      it 'raises an error' do
        expect(isin.cgs?).to be(false)
        expect { isin.to_cusip }.to raise_error(SecID::InvalidFormatError)
      end
    end

    context 'when BR country code' do
      let(:isin_number) { 'BRBBASACNOR3' }

      it 'is not a CGS country and raises an error' do
        expect(isin.cgs?).to be(false)
        expect { isin.to_cusip }.to raise_error(SecID::InvalidFormatError)
      end
    end

    context 'when round-trip conversion (ISIN -> CUSIP -> ISIN)' do
      let(:isin_number) { 'US0378331005' }

      it 'preserves ISIN value' do
        cusip = isin.to_cusip
        isin2 = cusip.to_isin('US')
        expect(isin.full_id).to eq(isin2.full_id)
      end
    end
  end

  describe '#nsin_type' do
    context 'when US ISIN' do
      let(:isin_number) { 'US0378331005' }

      it 'returns :cusip' do
        expect(isin.nsin_type).to eq(:cusip)
      end
    end

    context 'when CA ISIN' do
      let(:isin_number) { 'CA9861913023' }

      it 'returns :cusip' do
        expect(isin.nsin_type).to eq(:cusip)
      end
    end

    context 'when GB ISIN' do
      let(:isin_number) { 'GB00B02H2F76' }

      it 'returns :sedol' do
        expect(isin.nsin_type).to eq(:sedol)
      end
    end

    context 'when IE ISIN' do
      let(:isin_number) { 'IE00B296YR77' }

      it 'returns :sedol' do
        expect(isin.nsin_type).to eq(:sedol)
      end
    end

    context 'when DE ISIN' do
      let(:isin_number) { 'DE0007164600' }

      it 'returns :wkn' do
        expect(isin.nsin_type).to eq(:wkn)
      end
    end

    context 'when CH ISIN' do
      let(:isin_number) { 'CH0012221716' }

      it 'returns :valoren' do
        expect(isin.nsin_type).to eq(:valoren)
      end
    end

    context 'when LI ISIN' do
      let(:isin_number) { 'LI0000000000' }

      it 'returns :valoren' do
        expect(isin.nsin_type).to eq(:valoren)
      end
    end

    context 'when FR ISIN' do
      let(:isin_number) { 'FR0000120271' }

      it 'returns :generic' do
        expect(isin.nsin_type).to eq(:generic)
      end
    end
  end

  describe '#to_nsin' do
    context 'when US ISIN' do
      let(:isin_number) { 'US0378331005' }

      it 'returns CUSIP instance with correct value' do
        result = isin.to_nsin
        expect(result).to be_a(SecID::CUSIP)
        expect(result.full_id).to eq('037833100')
      end
    end

    context 'when GB ISIN' do
      let(:isin_number) { 'GB00B02H2F76' }

      it 'returns SEDOL instance with correct value' do
        result = isin.to_nsin
        expect(result).to be_a(SecID::SEDOL)
        expect(result.full_id).to eq('B02H2F7')
      end
    end

    context 'when DE ISIN' do
      let(:isin_number) { 'DE0007164600' }

      it 'returns WKN instance with correct value' do
        result = isin.to_nsin
        expect(result).to be_a(SecID::WKN)
        expect(result.full_id).to eq('716460')
      end
    end

    context 'when CH ISIN' do
      let(:isin_number) { 'CH0012221716' }

      it 'returns Valoren instance with correct value' do
        result = isin.to_nsin
        expect(result).to be_a(SecID::Valoren)
        expect(result.identifier).to eq('1222171')
      end
    end

    context 'when FR ISIN' do
      let(:isin_number) { 'FR0000120271' }

      it 'returns raw NSIN string' do
        result = isin.to_nsin
        expect(result).to be_a(String)
        expect(result).to eq('000012027')
      end
    end

    context 'when invalid format' do
      let(:isin_number) { '00B296YR77' }

      it 'raises InvalidFormatError' do
        expect { isin.to_nsin }.to raise_error(SecID::InvalidFormatError, 'Invalid ISIN format')
      end
    end
  end

  describe '#sedol?' do
    context 'when GB ISIN' do
      let(:isin_number) { 'GB00B02H2F76' }

      it 'returns true' do
        expect(isin.sedol?).to be(true)
      end
    end

    context 'when IE ISIN' do
      let(:isin_number) { 'IE00B296YR77' }

      it 'returns true' do
        expect(isin.sedol?).to be(true)
      end
    end

    context 'when US ISIN' do
      let(:isin_number) { 'US0378331005' }

      it 'returns false' do
        expect(isin.sedol?).to be(false)
      end
    end
  end

  describe '#wkn?' do
    context 'when DE ISIN' do
      let(:isin_number) { 'DE0007164600' }

      it 'returns true' do
        expect(isin.wkn?).to be(true)
      end
    end

    context 'when US ISIN' do
      let(:isin_number) { 'US0378331005' }

      it 'returns false' do
        expect(isin.wkn?).to be(false)
      end
    end
  end

  describe '#valoren?' do
    context 'when CH ISIN' do
      let(:isin_number) { 'CH0012221716' }

      it 'returns true' do
        expect(isin.valoren?).to be(true)
      end
    end

    context 'when LI ISIN' do
      let(:isin_number) { 'LI0000000000' }

      it 'returns true' do
        expect(isin.valoren?).to be(true)
      end
    end

    context 'when US ISIN' do
      let(:isin_number) { 'US0378331005' }

      it 'returns false' do
        expect(isin.valoren?).to be(false)
      end
    end
  end

  describe '#to_sedol' do
    context 'when GB ISIN' do
      let(:isin_number) { 'GB00B02H2F76' }

      it 'returns a SEDOL instance' do
        result = isin.to_sedol
        expect(result).to be_a(SecID::SEDOL)
        expect(result.full_id).to eq('B02H2F7')
      end
    end

    context 'when IE ISIN' do
      let(:isin_number) { 'IE00B296YR77' }

      it 'returns a SEDOL instance' do
        result = isin.to_sedol
        expect(result).to be_a(SecID::SEDOL)
        expect(result.full_id).to eq('B296YR7')
      end
    end

    context 'when IM ISIN' do
      let(:isin_number) { 'IM00B7S9G985' }

      it 'returns a SEDOL instance' do
        result = isin.to_sedol
        expect(result).to be_a(SecID::SEDOL)
        expect(result.full_id).to eq('B7S9G98')
      end
    end

    context 'when JE ISIN' do
      let(:isin_number) { 'JE00B4T3BW64' }

      it 'returns a SEDOL instance' do
        result = isin.to_sedol
        expect(result).to be_a(SecID::SEDOL)
        expect(result.full_id).to eq('B4T3BW6')
      end
    end

    context 'when GG ISIN' do
      let(:isin_number) { 'GG00BJVDZ946' }

      it 'returns a SEDOL instance' do
        result = isin.to_sedol
        expect(result).to be_a(SecID::SEDOL)
        expect(result.full_id).to eq('BJVDZ94')
      end
    end

    context 'when FK ISIN' do
      let(:isin_number) { 'FK00B030JM18' }

      it 'returns a SEDOL instance' do
        result = isin.to_sedol
        expect(result).to be_a(SecID::SEDOL)
        expect(result.full_id).to eq('B030JM1')
      end
    end

    context 'when non-SEDOL country code' do
      let(:isin_number) { 'US0378331005' }

      it 'raises InvalidFormatError' do
        expect { isin.to_sedol }.to raise_error(SecID::InvalidFormatError, "'US' is not a SEDOL country code!")
      end
    end
  end

  describe '#to_wkn' do
    context 'when DE ISIN' do
      let(:isin_number) { 'DE0007164600' }

      it 'returns a WKN instance' do
        result = isin.to_wkn
        expect(result).to be_a(SecID::WKN)
        expect(result.full_id).to eq('716460')
      end
    end

    context 'when non-WKN country code' do
      let(:isin_number) { 'US0378331005' }

      it 'raises InvalidFormatError' do
        expect { isin.to_wkn }.to raise_error(SecID::InvalidFormatError, "'US' is not a WKN country code!")
      end
    end
  end

  describe '#to_valoren' do
    context 'when CH ISIN' do
      let(:isin_number) { 'CH0012221716' }

      it 'returns a Valoren instance' do
        result = isin.to_valoren
        expect(result).to be_a(SecID::Valoren)
        expect(result.identifier).to eq('1222171')
      end
    end

    context 'when LI ISIN' do
      let(:isin_number) { 'LI0038863358' }

      it 'returns a Valoren instance' do
        result = isin.to_valoren
        expect(result).to be_a(SecID::Valoren)
        expect(result.identifier).to eq('3886335')
      end
    end

    context 'when non-Valoren country code' do
      let(:isin_number) { 'US0378331005' }

      it 'raises InvalidFormatError' do
        expect { isin.to_valoren }.to raise_error(SecID::InvalidFormatError, "'US' is not a Valoren country code!")
      end
    end
  end

  describe '.valid?' do
    context 'when ISIN is valid' do
      it 'returns true' do
        %w[
          US5949181045 US38259P5089 US0378331005 NL0000729408 JP3946600008
          DE000DZ21632 DE000DB7HWY7 DE000CM7VX13 CH0031240127 CA9861913023
        ].each do |isin_number|
          expect(described_class.valid?(isin_number)).to be(true)
        end

        expect(described_class.valid?('AU0000XVGZA3')).to be(true)
        expect(described_class.valid?('AU0000VXGZA3')).to be(true) # it's not a typo, it's a check-digit flaw in ISIN
      end
    end
  end

  describe '.restore!' do
    context 'when ISIN is valid' do
      it 'restores check-digit and returns instance' do
        expect(described_class.restore!('AU0000XVGZA').to_s).to eq('AU0000XVGZA3')
        expect(described_class.restore!('AU0000VXGZA7').to_s).to eq('AU0000VXGZA3')
        expect(described_class.restore!('GB000263494').to_s).to eq('GB0002634946')
        expect(described_class.restore!('US037833104').to_s).to eq('US0378331047')
        expect(described_class.restore!('US0378331004').to_s).to eq('US0378331005')
      end
    end
  end

  describe '.check_digit' do
    context 'when ISIN is valid' do
      it 'calculates and returns the check-digit' do
        expect(described_class.check_digit('AU0000XVGZA')).to eq(3)
        expect(described_class.check_digit('AU0000VXGZA7')).to eq(3)
        expect(described_class.check_digit('GB000263494')).to eq(6)
        expect(described_class.check_digit('US037833104')).to eq(7)
        expect(described_class.check_digit('US0378331004')).to eq(5)
      end
    end
  end

  describe '#to_pretty_s' do
    it 'formats as country_code + nsin + check_digit' do
      expect(described_class.new('US5949181045').to_pretty_s).to eq('US 594918104 5')
    end

    it 'formats another ISIN' do
      expect(described_class.new('IE00B296YR77').to_pretty_s).to eq('IE 00B296YR7 7')
    end
  end
end
