# frozen_string_literal: true

RSpec.describe SecId::ISIN do
  let(:isin) { described_class.new(isin_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

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
        expect(isin.to_cusip).to be_a(SecId::CUSIP)
      end
    end

    context 'when non-CGS country code' do
      let(:isin_number) { 'IE00B296YR77' }

      it 'raises an error' do
        expect(isin.cgs?).to be(false)
        expect { isin.to_cusip }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when BR country code' do
      let(:isin_number) { 'BRBBASACNOR3' }

      it 'is not a CGS country and raises an error' do
        expect(isin.cgs?).to be(false)
        expect { isin.to_cusip }.to raise_error(SecId::InvalidFormatError)
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
      it 'restores check-digit and returns full ISIN number' do
        expect(described_class.restore!('AU0000XVGZA')).to eq('AU0000XVGZA3')
        expect(described_class.restore!('AU0000VXGZA7')).to eq('AU0000VXGZA3')
        expect(described_class.restore!('GB000263494')).to eq('GB0002634946')
        expect(described_class.restore!('US037833104')).to eq('US0378331047')
        expect(described_class.restore!('US0378331004')).to eq('US0378331005')
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
end
