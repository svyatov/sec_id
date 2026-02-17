# frozen_string_literal: true

RSpec.describe SecID::IBAN do
  let(:iban) { described_class.new(iban_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'International Bank Account Number',
                  id_length: 15..34,
                  has_check_digit: true

  it_behaves_like 'a normalizable identifier',
                  valid_id: 'GB29NWBK60161331926819',
                  dirty_id: 'GB29 NWBK 6016 1331 9268 19',
                  invalid_id: 'INVALID'

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'DE89370400440532013000',
                  invalid_length_id: 'DE89',
                  invalid_chars_id: 'DE89370400440532013!!!'

  it_behaves_like 'a validate! identifier',
                  valid_id: 'DE89370400440532013000',
                  invalid_length_id: 'DE89',
                  invalid_chars_id: 'DE89370400440532013!!!'

  it_behaves_like 'detects invalid check digit',
                  valid_id: 'DE89370400440532013000',
                  invalid_check_digit_id: 'DE99370400440532013000'

  it_behaves_like 'validate! detects invalid check digit',
                  invalid_check_digit_id: 'DE99370400440532013000'

  # Core check-digit identifier behavior
  it_behaves_like 'a check-digit identifier',
                  valid_id: 'DE89370400440532013000',
                  valid_id_without_check: 'DE370400440532013000',
                  restored_id: 'DE89370400440532013000',
                  invalid_format_id: 'INVALID',
                  invalid_check_digit_id: 'DE99370400440532013000',
                  expected_check_digit: 89

  describe '#check_digit_width' do
    it 'returns 2' do
      iban = described_class.new('DE89370400440532013000')
      expect(iban.__send__(:check_digit_width)).to eq(2)
    end
  end

  context 'when IBAN is valid (Germany)' do
    let(:iban_number) { 'DE89370400440532013000' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('DE')
      expect(iban.check_digit).to eq(89)
      expect(iban.bban).to eq('370400440532013000')
      expect(iban.identifier).to eq('DE370400440532013000')
    end

    it 'extracts BBAN components' do
      expect(iban.bank_code).to eq('37040044')
      expect(iban.account_number).to eq('0532013000')
      expect(iban.branch_code).to be_nil
      expect(iban.national_check).to be_nil
    end

    describe '#to_s' do
      it 'returns full IBAN' do
        expect(iban.to_s).to eq(iban_number)
      end
    end

    describe '#known_country?' do
      it 'returns true' do
        expect(iban.known_country?).to be(true)
      end
    end
  end

  context 'when IBAN is valid (France)' do
    let(:iban_number) { 'FR1420041010050500013M02606' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('FR')
      expect(iban.check_digit).to eq(14)
      expect(iban.bban).to eq('20041010050500013M02606')
    end

    it 'extracts BBAN components' do
      expect(iban.bank_code).to eq('20041')
      expect(iban.branch_code).to eq('01005')
      expect(iban.account_number).to eq('0500013M026')
      expect(iban.national_check).to eq('06')
    end

    describe '#valid?' do
      it 'returns true' do
        expect(iban.valid?).to be(true)
      end
    end
  end

  context 'when IBAN is valid (United Kingdom)' do
    let(:iban_number) { 'GB29NWBK60161331926819' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('GB')
      expect(iban.check_digit).to eq(29)
      expect(iban.bban).to eq('NWBK60161331926819')
    end

    it 'extracts BBAN components' do
      expect(iban.bank_code).to eq('NWBK')
      expect(iban.branch_code).to eq('601613')
      expect(iban.account_number).to eq('31926819')
    end

    describe '#valid?' do
      it 'returns true' do
        expect(iban.valid?).to be(true)
      end
    end
  end

  context 'when IBAN is valid (Spain)' do
    let(:iban_number) { 'ES9121000418450200051332' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('ES')
      expect(iban.check_digit).to eq(91)
      expect(iban.bban).to eq('21000418450200051332')
    end

    it 'extracts BBAN components' do
      expect(iban.bank_code).to eq('2100')
      expect(iban.branch_code).to eq('0418')
      expect(iban.national_check).to eq('45')
      expect(iban.account_number).to eq('0200051332')
    end

    describe '#valid?' do
      it 'returns true' do
        expect(iban.valid?).to be(true)
      end
    end
  end

  context 'when IBAN is valid (Netherlands)' do
    let(:iban_number) { 'NL91ABNA0417164300' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('NL')
      expect(iban.check_digit).to eq(91)
      expect(iban.bban).to eq('ABNA0417164300')
    end

    it 'extracts BBAN components' do
      expect(iban.bank_code).to eq('ABNA')
      expect(iban.account_number).to eq('0417164300')
    end

    describe '#valid?' do
      it 'returns true' do
        expect(iban.valid?).to be(true)
      end
    end
  end

  context 'when IBAN is valid (Belgium)' do
    let(:iban_number) { 'BE68539007547034' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('BE')
      expect(iban.check_digit).to eq(68)
      expect(iban.bban).to eq('539007547034')
    end

    it 'extracts BBAN components' do
      expect(iban.bank_code).to eq('539')
      expect(iban.account_number).to eq('0075470')
      expect(iban.national_check).to eq('34')
    end

    describe '#valid?' do
      it 'returns true' do
        expect(iban.valid?).to be(true)
      end
    end
  end

  context 'when IBAN is valid (Italy)' do
    let(:iban_number) { 'IT60X0542811101000000123456' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('IT')
      expect(iban.check_digit).to eq(60)
      expect(iban.bban).to eq('X0542811101000000123456')
    end

    it 'extracts BBAN components' do
      expect(iban.national_check).to eq('X')
      expect(iban.bank_code).to eq('05428')
      expect(iban.branch_code).to eq('11101')
      expect(iban.account_number).to eq('000000123456')
    end

    describe '#valid?' do
      it 'returns true' do
        expect(iban.valid?).to be(true)
      end
    end
  end

  context 'when IBAN is valid (Switzerland)' do
    let(:iban_number) { 'CH9300762011623852957' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('CH')
      expect(iban.check_digit).to eq(93)
      expect(iban.bban).to eq('00762011623852957')
    end

    it 'extracts BBAN components' do
      expect(iban.bank_code).to eq('00762')
      expect(iban.account_number).to eq('011623852957')
    end

    describe '#valid?' do
      it 'returns true' do
        expect(iban.valid?).to be(true)
      end
    end
  end

  context 'when IBAN is valid (Austria)' do
    let(:iban_number) { 'AT611904300234573201' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('AT')
      expect(iban.check_digit).to eq(61)
      expect(iban.bban).to eq('1904300234573201')
    end

    it 'extracts BBAN components' do
      expect(iban.bank_code).to eq('19043')
      expect(iban.account_number).to eq('00234573201')
    end

    describe '#valid?' do
      it 'returns true' do
        expect(iban.valid?).to be(true)
      end
    end
  end

  context 'when IBAN is missing check-digit' do
    let(:iban_number) { 'DE370400440532013000' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('DE')
      expect(iban.bban).to eq('370400440532013000')
      expect(iban.check_digit).to be_nil
    end
  end

  context 'when IBAN format is invalid' do
    let(:iban_number) { 'INVALID' }

    it 'parses IBAN as nil' do
      expect(iban.country_code).to be_nil
      expect(iban.bban).to be_nil
      expect(iban.check_digit).to be_nil
      expect(iban.identifier).to be_nil
    end
  end

  context 'when IBAN has invalid BBAN length for country' do
    let(:iban_number) { 'DE8937040044053201' } # 16 chars instead of 18

    it 'parses country code and BBAN' do
      expect(iban.country_code).to eq('DE')
      expect(iban.bban).to eq('37040044053201')
    end

    describe '#valid?' do
      it 'returns false' do
        expect(iban.valid?).to be(false)
      end
    end

    describe '#valid_bban_format?' do
      it 'returns false' do
        expect(iban.valid_bban_format?).to be(false)
      end
    end
  end

  context 'when IBAN has invalid BBAN format for country' do
    let(:iban_number) { 'DE89ABCD00440532013000' } # Letters in BBAN for DE (should be all digits)

    it 'parses country code and BBAN' do
      expect(iban.country_code).to eq('DE')
      expect(iban.bban).to eq('ABCD00440532013000')
    end
  end

  context 'when IBAN contains lowercase letters' do
    let(:iban_number) { 'de89370400440532013000' }

    it 'normalizes to uppercase and parses correctly' do
      expect(iban.country_code).to eq('DE')
      expect(iban.check_digit).to eq(89)
      expect(iban.bban).to eq('370400440532013000')
      expect(iban.valid?).to be(true)
    end
  end

  context 'when IBAN is from length-only validated country (Saudi Arabia)' do
    let(:iban_number) { 'SA0380000000608010167519' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('SA')
      expect(iban.check_digit).to eq(3)
      expect(iban.bban).to eq('80000000608010167519')
    end

    it 'does not extract BBAN components' do
      expect(iban.bank_code).to be_nil
      expect(iban.account_number).to be_nil
    end

    describe '#valid?' do
      it 'returns true' do
        expect(iban.valid?).to be(true)
      end
    end

    describe '#known_country?' do
      it 'returns true' do
        expect(iban.known_country?).to be(true)
      end
    end
  end

  context 'when IBAN is from unknown country' do
    let(:iban_number) { 'XX00123456789012345' }

    it 'parses IBAN correctly' do
      expect(iban.country_code).to eq('XX')
      expect(iban.bban).to eq('123456789012345')
    end

    describe '#known_country?' do
      it 'returns false' do
        expect(iban.known_country?).to be(false)
      end
    end
  end

  describe '#errors' do
    context 'when BBAN format is invalid for country' do
      it 'returns :invalid_bban error with descriptive message' do
        # Letters in BBAN for DE (should be all digits)
        result = described_class.new('DE89ABCD00440532013000').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_bban])
        expect(result.details.first[:message]).to match(/BBAN/)
      end
    end

    context 'when BBAN length is wrong for country' do
      it 'returns :invalid_bban error' do
        result = described_class.new('DE8937040044053201').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_bban])
      end
    end
  end

  describe '#validate!' do
    context 'when BBAN format is invalid' do
      it 'raises InvalidStructureError' do
        expect { described_class.new('DE89ABCD00440532013000').validate! }
          .to raise_error(SecID::InvalidStructureError, /BBAN/)
      end
    end
  end

  describe '.valid?' do
    context 'when IBAN is valid' do
      # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
      it 'returns true for real-world examples from various countries' do
        expect(described_class.valid?('DE89370400440532013000')).to be(true) # Germany
        expect(described_class.valid?('FR1420041010050500013M02606')).to be(true) # France
        expect(described_class.valid?('GB29NWBK60161331926819')).to be(true) # UK
        expect(described_class.valid?('ES9121000418450200051332')).to be(true) # Spain
        expect(described_class.valid?('NL91ABNA0417164300')).to be(true) # Netherlands
        expect(described_class.valid?('BE68539007547034')).to be(true) # Belgium
        expect(described_class.valid?('IT60X0542811101000000123456')).to be(true) # Italy
        expect(described_class.valid?('CH9300762011623852957')).to be(true) # Switzerland
        expect(described_class.valid?('AT611904300234573201')).to be(true) # Austria
        expect(described_class.valid?('PL61109010140000071219812874')).to be(true) # Poland
        expect(described_class.valid?('SE4550000000058398257466')).to be(true) # Sweden
        expect(described_class.valid?('NO9386011117947')).to be(true) # Norway
        expect(described_class.valid?('DK5000400440116243')).to be(true) # Denmark
        expect(described_class.valid?('FI2112345600000785')).to be(true) # Finland
        expect(described_class.valid?('PT50000201231234567890154')).to be(true) # Portugal
        expect(described_class.valid?('IE29AIBK93115212345678')).to be(true) # Ireland
      end
      # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
    end
  end

  describe '.restore!' do
    context 'when IBAN format is valid' do
      it 'restores check-digit for various IBANs' do
        expect(described_class.restore!('DE370400440532013000').to_s).to eq('DE89370400440532013000')
        expect(described_class.restore!('DE99370400440532013000').to_s).to eq('DE89370400440532013000')
        expect(described_class.restore!('NLABNA0417164300').to_s).to eq('NL91ABNA0417164300')
        expect(described_class.restore!('GB29NWBK60161331926819').to_s).to eq('GB29NWBK60161331926819')
      end
    end
  end

  describe '.check_digit' do
    context 'when IBAN format is valid' do
      it 'calculates check-digit for various IBANs' do
        expect(described_class.check_digit('DE370400440532013000')).to eq(89)
        expect(described_class.check_digit('DE89370400440532013000')).to eq(89)
        expect(described_class.check_digit('GBNWBK60161331926819')).to eq(29)
        expect(described_class.check_digit('ES21000418450200051332')).to eq(91)
        expect(described_class.check_digit('NL91ABNA0417164300')).to eq(91)
      end
    end
  end

  describe '#country_rule' do
    context 'when country has explicit rules' do
      let(:iban_number) { 'DE89370400440532013000' }

      it 'returns the country rule hash' do
        expect(iban.country_rule).to be_a(Hash)
        expect(iban.country_rule[:length]).to eq(18)
        expect(iban.country_rule[:format]).to eq(/\A\d{18}\z/)
        expect(iban.country_rule[:components]).to include(:bank_code, :account_number)
      end
    end

    context 'when country has length-only validation' do
      let(:iban_number) { 'SA0380000000608010167519' }

      it 'returns nil' do
        expect(iban.country_rule).to be_nil
      end
    end
  end

  # Test additional EU/EEA countries for structural validation
  describe 'EU/EEA country validation' do
    {
      'AT' => { iban: 'AT611904300234573201', length: 16 },
      'BE' => { iban: 'BE68539007547034', length: 12 },
      'BG' => { iban: 'BG80BNBG96611020345678', length: 18 },
      'CH' => { iban: 'CH9300762011623852957', length: 17 },
      'CY' => { iban: 'CY17002001280000001200527600', length: 24 },
      'CZ' => { iban: 'CZ6508000000192000145399', length: 20 },
      'DE' => { iban: 'DE89370400440532013000', length: 18 },
      'DK' => { iban: 'DK5000400440116243', length: 14 },
      'EE' => { iban: 'EE382200221020145685', length: 16 },
      'ES' => { iban: 'ES9121000418450200051332', length: 20 },
      'FI' => { iban: 'FI2112345600000785', length: 14 },
      'FR' => { iban: 'FR1420041010050500013M02606', length: 23 },
      'GB' => { iban: 'GB29NWBK60161331926819', length: 18 },
      'GR' => { iban: 'GR1601101250000000012300695', length: 23 },
      'HR' => { iban: 'HR1210010051863000160', length: 17 },
      'HU' => { iban: 'HU42117730161111101800000000', length: 24 },
      'IE' => { iban: 'IE29AIBK93115212345678', length: 18 },
      'IS' => { iban: 'IS140159260076545510730339', length: 22 },
      'IT' => { iban: 'IT60X0542811101000000123456', length: 23 },
      'LI' => { iban: 'LI21088100002324013AA', length: 17 },
      'LT' => { iban: 'LT121000011101001000', length: 16 },
      'LU' => { iban: 'LU280019400644750000', length: 16 },
      'LV' => { iban: 'LV80BANK0000435195001', length: 17 },
      'MC' => { iban: 'MC5811222000010123456789030', length: 23 },
      'MT' => { iban: 'MT84MALT011000012345MTLCAST001S', length: 27 },
      'NL' => { iban: 'NL91ABNA0417164300', length: 14 },
      'NO' => { iban: 'NO9386011117947', length: 11 },
      'PL' => { iban: 'PL61109010140000071219812874', length: 24 },
      'PT' => { iban: 'PT50000201231234567890154', length: 21 },
      'RO' => { iban: 'RO49AAAA1B31007593840000', length: 20 },
      'SE' => { iban: 'SE4550000000058398257466', length: 20 },
      'SI' => { iban: 'SI56263300012039086', length: 15 },
      'SK' => { iban: 'SK3112000000198742637541', length: 20 },
      'SM' => { iban: 'SM86U0322509800000000270100', length: 23 }
    }.each do |country, data|
      context "when IBAN is from #{country}" do
        let(:iban_number) { data[:iban] }

        it 'validates correctly' do
          expect(iban.valid?).to be(true), "Expected #{country} IBAN #{data[:iban]} to be valid"
        end

        it "has BBAN length of #{data[:length]}" do
          expect(iban.bban.length).to eq(data[:length])
        end
      end
    end
  end

  # Test length-only countries
  describe 'length-only country validation' do
    {
      'SA' => { iban: 'SA0380000000608010167519', length: 20 },
      'AE' => { iban: 'AE070331234567890123456', length: 19 },
      'TR' => { iban: 'TR330006100519786457841326', length: 22 }
    }.each do |country, data|
      context "when IBAN is from #{country}" do
        let(:iban_number) { data[:iban] }

        it 'validates correctly' do
          expect(iban.valid?).to be(true), "Expected #{country} IBAN #{data[:iban]} to be valid"
        end

        it 'is a known country' do
          expect(iban.known_country?).to be(true)
        end

        it 'does not extract BBAN components' do
          expect(iban.bank_code).to be_nil
        end
      end
    end
  end
end
