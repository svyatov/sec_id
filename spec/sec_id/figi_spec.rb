# frozen_string_literal: true

RSpec.describe SecID::FIGI do
  let(:figi) { described_class.new(figi_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Financial Instrument Global Identifier',
                  id_length: 12,
                  has_checksum: true

  it_behaves_like 'a generatable identifier'

  it_behaves_like 'a normalizable identifier',
                  valid_id: 'BBG000BLNNH6',
                  dirty_id: 'bbg-000-blnnh6',
                  invalid_id: 'INVALID'

  it_behaves_like 'a formattable identifier',
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

  it_behaves_like 'detects invalid checksum',
                  valid_id: 'BBG000H4FSM0',
                  invalid_checksum_id: 'BBG000H4FSM5'

  it_behaves_like 'validate! detects invalid checksum',
                  invalid_checksum_id: 'BBG000H4FSM5'

  # Serialization
  it_behaves_like 'a hashable identifier',
                  valid_id: 'BBG000BLNNH6',
                  invalid_id: 'INVALID',
                  expected_type: :figi,
                  expected_components: { prefix: 'BB', random_part: '000BLNNH', checksum: 6 }

  # Core checksum identifier behavior
  it_behaves_like 'a checksum identifier',
                  valid_id: 'BBG000H4FSM0',
                  valid_id_without_check: 'BBG000H4FSM',
                  restored_id: 'BBG000H4FSM0',
                  invalid_format_id: 'G000BLNQ16',
                  invalid_checksum_id: 'BBG000H4FSM5',
                  expected_checksum: 0

  context 'when FIGI is valid' do
    let(:figi_number) { 'BBG000H4FSM0' }

    it 'parses FIGI correctly' do
      expect(figi.identifier).to eq('BBG000H4FSM')
      expect(figi.prefix).to eq('BB')
      expect(figi.random_part).to eq('000H4FSM')
      expect(figi.checksum).to eq(0)
    end
  end

  context 'when FIGI has a restricted prefix' do
    let(:figi_number) { 'BSGF4YQD8PV0' }

    it 'parses FIGI correctly' do
      expect(figi.identifier).to eq('BSGF4YQD8PV')
      expect(figi.prefix).to eq('BS')
      expect(figi.random_part).to eq('F4YQD8PV')
      expect(figi.checksum).to eq(0)
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
      expect(figi.checksum).to be_nil
    end
  end

  context 'when FIGI number is missing checksum' do
    let(:figi_number) { 'BBG000BLNQ1' }

    it 'parses FIGI correctly' do
      expect(figi.identifier).to eq(figi_number)
      expect(figi.prefix).to eq('BB')
      expect(figi.random_part).to eq('000BLNQ1')
      expect(figi.checksum).to be_nil
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
      it 'restores checksum for various FIGIs' do
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
        expect(result.details.first[:message]).to include('restricted')
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

  describe '.checksum' do
    context 'when FIGI is valid' do
      it 'calculates checksum for various FIGIs' do
        expect(described_class.checksum('BBG000HY4HW')).to eq(9)
        expect(described_class.checksum('BBG000HY4HW9')).to eq(9)
        expect(described_class.checksum('BBG000BCK0D')).to eq(3)
        expect(described_class.checksum('BBG000BCK0D3')).to eq(3)
        expect(described_class.checksum('BBG000BKRK3')).to eq(5)
      end
    end
  end

  describe '#to_pretty_s' do
    it 'formats as prefix+G + random_part + checksum' do
      expect(described_class.new('BBG000BLNQ16').to_pretty_s).to eq('BBG 000BLNQ1 6')
    end
  end

  describe '.generate' do
    it 'uses a non-reserved prefix and a vowel-free random part' do
      figi = described_class.generate
      expect(described_class::RESTRICTED_PREFIXES).not_to include(figi.prefix)
      expect(figi.random_part).to match(/\A[B-DF-HJ-NP-TV-Z0-9]{8}\z/)
    end

    it 'resamples when the first draw is a restricted prefix' do
      # Seed 3's first two-character draw is the restricted prefix 'BS', forcing the
      # rejection-sampling loop to retry until it lands on a permitted prefix.
      figi = described_class.generate(random: Random.new(3))
      expect(figi.prefix).not_to eq('BS')
      expect(described_class::RESTRICTED_PREFIXES).not_to include(figi.prefix)
    end

    it 'never returns a restricted prefix across many seeds' do
      (0..300).each do |seed|
        prefix = described_class.generate(random: Random.new(seed)).prefix
        expect(described_class::RESTRICTED_PREFIXES).not_to include(prefix)
      end
    end
  end
end
