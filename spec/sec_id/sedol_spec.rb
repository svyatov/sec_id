# frozen_string_literal: true

RSpec.describe SecId::SEDOL do
  let(:sedol) { described_class.new(sedol_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Stock Exchange Daily Official List',
                  id_length: 7,
                  has_check_digit: true

  it_behaves_like 'a normalizable identifier',
                  valid_id: 'B0YBKJ7',
                  dirty_id: 'b0y bkj7',
                  invalid_id: 'INVALID'

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'B19GKT4',
                  invalid_length_id: 'B1',
                  invalid_chars_id: 'B19AKT4'

  it_behaves_like 'a validate! identifier',
                  valid_id: 'B19GKT4',
                  invalid_length_id: 'B1',
                  invalid_chars_id: 'B19AKT4'

  it_behaves_like 'detects invalid check digit',
                  valid_id: 'B19GKT4',
                  invalid_check_digit_id: 'B19GKT0'

  it_behaves_like 'validate! detects invalid check digit',
                  invalid_check_digit_id: 'B19GKT0'

  # Core check-digit identifier behavior
  it_behaves_like 'a check-digit identifier',
                  valid_id: 'B19GKT4',
                  valid_id_without_check: 'B19GKT',
                  restored_id: 'B19GKT4',
                  invalid_format_id: 'A61351',
                  invalid_check_digit_id: 'B19GKT0',
                  expected_check_digit: 4

  context 'when SEDOL is valid' do
    let(:sedol_number) { 'B19GKT4' }

    it 'parses SEDOL correctly' do
      expect(sedol.identifier).to eq('B19GKT')
      expect(sedol.check_digit).to eq(4)
    end
  end

  context 'when SEDOL number is missing check-digit' do
    let(:sedol_number) { '552902' }

    it 'parses SEDOL number correctly' do
      expect(sedol.identifier).to eq(sedol_number)
      expect(sedol.check_digit).to be_nil
    end
  end

  describe '.valid?' do
    context 'when SEDOL is valid' do
      it 'returns true for various valid SEDOLs' do
        %w[
          2307389 5529027 B03MLX2 B0Z52W5 B19GKT4 6135111
        ].each do |sedol_number|
          expect(described_class.valid?(sedol_number)).to be(true)
        end
      end
    end
  end

  describe '.restore!' do
    context 'when SEDOL is valid' do
      it 'restores check-digit for various SEDOLs' do
        expect(described_class.restore!('B09CBL').to_s).to eq('B09CBL4')
        expect(described_class.restore!('219071').to_s).to eq('2190716')
        expect(described_class.restore!('B923455').to_s).to eq('B923452')
        expect(described_class.restore!('B99876').to_s).to eq('B998762')
        expect(described_class.restore!('2307380').to_s).to eq('2307389')
      end
    end
  end

  describe '.check_digit' do
    context 'when SEDOL is valid' do
      it 'calculates check-digit for various SEDOLs' do
        expect(described_class.check_digit('554389')).to eq(0)
        expect(described_class.check_digit('2190716')).to eq(6)
        expect(described_class.check_digit('B0Z52W')).to eq(5)
        expect(described_class.check_digit('B19GKT4')).to eq(4)
        expect(described_class.check_digit('613511')).to eq(1)
      end
    end
  end

  describe '#to_isin' do
    context 'when SEDOL is valid' do
      let(:sedol_number) { 'B02H2F7' }

      it 'returns an ISIN instance for default GB country code' do
        result = sedol.to_isin
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_id).to eq('GB00B02H2F76')
        expect(result.country_code).to eq('GB')
      end

      it 'returns an ISIN instance for IE country code' do
        result = sedol.to_isin('IE')
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_id).to eq('IE00B02H2F76')
        expect(result.country_code).to eq('IE')
      end

      it 'raises InvalidFormatError for invalid country code' do
        expect { sedol.to_isin('US') }.to raise_error(
          SecId::InvalidFormatError, "'US' is not a valid SEDOL country code!"
        )
      end
    end

    context 'when IM country code' do
      let(:sedol_number) { 'B7S9G98' }

      it 'returns an ISIN instance for IM country code' do
        result = sedol.to_isin('IM')
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_id).to eq('IM00B7S9G985')
        expect(result.country_code).to eq('IM')
      end
    end

    context 'when JE country code' do
      let(:sedol_number) { 'B4T3BW6' }

      it 'returns an ISIN instance for JE country code' do
        result = sedol.to_isin('JE')
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_id).to eq('JE00B4T3BW64')
        expect(result.country_code).to eq('JE')
      end
    end

    context 'when GG country code' do
      let(:sedol_number) { 'BPFJTF4' }

      it 'returns an ISIN instance for GG country code' do
        result = sedol.to_isin('GG')
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_id).to eq('GG00BPFJTF46')
        expect(result.country_code).to eq('GG')
      end
    end

    context 'when FK country code' do
      let(:sedol_number) { 'B030JM1' }

      it 'returns an ISIN instance for FK country code' do
        result = sedol.to_isin('FK')
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_id).to eq('FK00B030JM18')
        expect(result.country_code).to eq('FK')
      end
    end

    context 'when SEDOL is missing check digit' do
      let(:sedol_number) { 'B02H2F' }

      it 'returns valid ISIN without mutating source SEDOL' do
        result = sedol.to_isin
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_id).to eq('GB00B02H2F76')
        expect(sedol.full_id).to eq('B02H2F')
        expect(sedol.check_digit).to be_nil
      end
    end

    context 'when SEDOL has wrong check digit' do
      let(:sedol_number) { 'B02H2F0' }

      it 'produces valid ISIN with correct check digit' do
        result = sedol.to_isin
        expect(result).to be_a(SecId::ISIN)
        expect(result.valid?).to be(true)
        expect(result.full_id).to eq('GB00B02H2F76')
      end
    end

    context 'when round-trip conversion' do
      let(:sedol_number) { 'B02H2F7' }

      it 'preserves SEDOL value' do
        isin = sedol.to_isin
        sedol2 = isin.to_sedol
        expect(sedol.full_id).to eq(sedol2.full_id)
      end
    end
  end
end
