# frozen_string_literal: true

RSpec.describe SecId::CUSIP do
  # Edge cases - applicable to all identifiers
  let(:cusip) { described_class.new(cusip_number) }

  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Committee on Uniform Securities Identification Procedures',
                  id_length: 9,
                  has_check_digit: true,
                  has_normalization: false

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: '037833100',
                  invalid_length_id: '0378',
                  invalid_chars_id: '03783310!'

  it_behaves_like 'detects invalid check digit',
                  valid_id: '68389X105',
                  invalid_check_digit_id: '68389X100'

  # Core check-digit identifier behavior
  it_behaves_like 'a check-digit identifier',
                  valid_id: '68389X105',
                  valid_id_without_check: '68389X10',
                  restored_id: '68389X105',
                  invalid_format_id: '5949181',
                  invalid_check_digit_id: '68389X100',
                  expected_check_digit: 5

  context 'when CUSIP is valid' do
    let(:cusip_number) { '68389X105' }

    it 'parses CUSIP correctly' do
      expect(cusip.identifier).to eq('68389X10')
      expect(cusip.cusip6).to eq('68389X')
      expect(cusip.issue).to eq('10')
      expect(cusip.check_digit).to eq(5)
    end
  end

  context 'when CUSIP number is missing check-digit' do
    let(:cusip_number) { '38259P50' }

    it 'parses CUSIP number correctly' do
      expect(cusip.identifier).to eq(cusip_number)
      expect(cusip.cusip6).to eq('38259P')
      expect(cusip.issue).to eq('50')
      expect(cusip.check_digit).to be_nil
    end
  end

  describe '.valid?' do
    context 'when CUSIP is valid' do
      it 'returns true for various valid CUSIPs' do
        %w[
          594918104 38259P508 037833100 17275R102 68389X105 986191302
        ].each do |cusip_number|
          expect(described_class.valid?(cusip_number)).to be(true)
        end
      end
    end
  end

  describe '#to_isin' do
    context 'when CGS country code' do
      let(:cusip_number) { '02153X108' }

      it 'returns an ISIN' do
        expect(cusip.to_isin('VI')).to be_a(SecId::ISIN)
      end
    end

    context 'when non-CGS country code' do
      let(:cusip_number) { '00B296YR7' }

      it 'raises an error' do
        expect { cusip.to_isin('IE') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when CUSIP is missing check digit' do
      let(:cusip_number) { '59491810' }

      it 'returns valid ISIN without mutating source CUSIP' do
        result = cusip.to_isin('US')
        expect(result).to be_a(SecId::ISIN)
        expect(result.full_number).to eq('US5949181045')
        expect(cusip.full_number).to eq('59491810')
        expect(cusip.check_digit).to be_nil
      end
    end
  end

  describe '#cins?' do
    context 'when a CINS' do
      let(:cusip_number) { 'G0052B105' }

      it 'returns true' do
        expect(cusip.cins?).to be(true)
      end
    end

    context 'when not a CINS' do
      let(:cusip_number) { '084664BL4' }

      it 'returns false' do
        expect(cusip.cins?).to be(false)
      end
    end
  end

  describe '.restore!' do
    context 'when CUSIP is valid' do
      it 'restores check-digit for various CUSIPs' do
        expect(described_class.restore!('03783310')).to eq('037833100')
        expect(described_class.restore!('17275R10')).to eq('17275R102')
        expect(described_class.restore!('38259P50')).to eq('38259P508')
        expect(described_class.restore!('59491810')).to eq('594918104')
        expect(described_class.restore!('68389X10')).to eq('68389X105')
      end
    end
  end

  describe '.valid_format?' do
    context 'when CUSIP is valid or missing check-digit' do
      it 'returns true for various valid formats' do
        expect(described_class.valid_format?('38259P50')).to be(true)
        expect(described_class.valid_format?('38259P508')).to be(true)
        expect(described_class.valid_format?('68389X10')).to be(true)
        expect(described_class.valid_format?('68389X105')).to be(true)
        expect(described_class.valid_format?('986191302')).to be(true)
      end
    end
  end

  describe '.check_digit' do
    context 'when CUSIP is valid' do
      it 'calculates check-digit for various CUSIPs' do
        expect(described_class.check_digit('03783310')).to eq(0)
        expect(described_class.check_digit('17275R10')).to eq(2)
        expect(described_class.check_digit('38259P50')).to eq(8)
        expect(described_class.check_digit('59491810')).to eq(4)
        expect(described_class.check_digit('68389X10')).to eq(5)
      end
    end
  end
end
