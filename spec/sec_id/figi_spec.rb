# frozen_string_literal: true

RSpec.describe SecID::FIGI do
  let(:figi) { described_class.new(figi_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Financial Instrument Global Identifier',
                  id_length: 12,
                  has_check_digit: true

  it_behaves_like 'a normalizable identifier',
                  valid_id: 'BBG000BLNNH6',
                  dirty_id: 'bbg-000-blnnh6',
                  invalid_id: 'INVALID'

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'BBG000H4FSM0',
                  invalid_length_id: 'BBG',
                  invalid_chars_id: 'BBG000H!FSM0'

  it_behaves_like 'a validate! identifier',
                  valid_id: 'BBG000H4FSM0',
                  invalid_length_id: 'BBG',
                  invalid_chars_id: 'BBG000H!FSM0'

  it_behaves_like 'detects invalid check digit',
                  valid_id: 'BBG000H4FSM0',
                  invalid_check_digit_id: 'BBG000H4FSM5'

  it_behaves_like 'validate! detects invalid check digit',
                  invalid_check_digit_id: 'BBG000H4FSM5'

  # Core check-digit identifier behavior
  it_behaves_like 'a check-digit identifier',
                  valid_id: 'BBG000H4FSM0',
                  valid_id_without_check: 'BBG000H4FSM',
                  restored_id: 'BBG000H4FSM0',
                  invalid_format_id: 'G000BLNQ16',
                  invalid_check_digit_id: 'BBG000H4FSM5',
                  expected_check_digit: 0

  context 'when FIGI is valid' do
    let(:figi_number) { 'BBG000H4FSM0' }

    it 'parses FIGI correctly' do
      expect(figi.identifier).to eq('BBG000H4FSM')
      expect(figi.prefix).to eq('BB')
      expect(figi.random_part).to eq('000H4FSM')
      expect(figi.check_digit).to eq(0)
    end
  end

  context 'when FIGI has a restricted prefix' do
    let(:figi_number) { 'BSGF4YQD8PV0' }

    it 'parses FIGI correctly' do
      expect(figi.identifier).to eq('BSGF4YQD8PV')
      expect(figi.prefix).to eq('BS')
      expect(figi.random_part).to eq('F4YQD8PV')
      expect(figi.check_digit).to eq(0)
    end

    describe '#valid?' do
      it 'returns false' do
        expect(figi.valid?).to be(false)
      end
    end

    describe '#restore!' do
      it 'raises an error' do
        expect { figi.restore! }.to raise_error(SecID::InvalidFormatError)
      end
    end
  end

  context 'when FIGI is missing prefix' do
    let(:figi_number) { 'G000BLNQ16' }

    it 'parses FIGI correctly' do
      expect(figi.identifier).to be_nil
      expect(figi.prefix).to be_nil
      expect(figi.random_part).to be_nil
      expect(figi.check_digit).to be_nil
    end
  end

  context 'when FIGI number is missing check-digit' do
    let(:figi_number) { 'BBG000BLNQ1' }

    it 'parses FIGI correctly' do
      expect(figi.identifier).to eq(figi_number)
      expect(figi.prefix).to eq('BB')
      expect(figi.random_part).to eq('000BLNQ1')
      expect(figi.check_digit).to be_nil
    end
  end

  describe '.valid?' do
    context 'when FIGI is valid' do
      it 'returns true for various valid FIGIs' do
        %w[KKG000000M81 BBG008B8STT7 BBG00QRVW6J5 BBG001S6RDX9 BBG000CJYWS6].each do |figi_number|
          expect(described_class.valid?(figi_number)).to be(true)
        end
      end
    end
  end

  describe '.restore!' do
    context 'when FIGI is valid' do
      it 'restores check-digit for various FIGIs' do
        expect(described_class.restore!('BBG000HY4HW').to_s).to eq('BBG000HY4HW9')
        expect(described_class.restore!('BBG000HY4HW9').to_s).to eq('BBG000HY4HW9')
        expect(described_class.restore!('BBG000BCK0D').to_s).to eq('BBG000BCK0D3')
        expect(described_class.restore!('BBG000BCK0D3').to_s).to eq('BBG000BCK0D3')
        expect(described_class.restore!('BBG000BKRK3').to_s).to eq('BBG000BKRK35')
      end
    end
  end

  describe '#errors' do
    context 'when prefix is restricted' do
      it 'returns :invalid_prefix error with descriptive message' do
        result = described_class.new('BSG000BLNNH6').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_prefix])
        expect(result.details.first[:message]).to match(/restricted/)
      end
    end

    context 'when prefix is restricted (validate!)' do
      it 'raises InvalidStructureError' do
        expect { described_class.new('BSG000BLNNH6').validate! }
          .to raise_error(SecID::InvalidStructureError, /restricted/)
      end
    end

    context 'when prefix is restricted (various)' do
      %w[BSG BMG GGG GBG GHG KYG VGG].each do |prefix|
        it "detects restricted prefix #{prefix[0..1]}" do
          result = described_class.new("#{prefix}000BLNNH6").errors
          expect(result.details.map { |d| d[:error] }).to include(:invalid_prefix)
        end
      end
    end
  end

  describe '.check_digit' do
    context 'when FIGI is valid' do
      it 'calculates check-digit for various FIGIs' do
        expect(described_class.check_digit('BBG000HY4HW')).to eq(9)
        expect(described_class.check_digit('BBG000HY4HW9')).to eq(9)
        expect(described_class.check_digit('BBG000BCK0D')).to eq(3)
        expect(described_class.check_digit('BBG000BCK0D3')).to eq(3)
        expect(described_class.check_digit('BBG000BKRK3')).to eq(5)
      end
    end
  end
end
