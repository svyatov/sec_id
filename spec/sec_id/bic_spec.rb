# frozen_string_literal: true

RSpec.describe SecID::BIC do
  let(:bic) { described_class.new(bic_code) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Business Identifier Code',
                  id_length: [8, 11],
                  has_checksum: false

  it_behaves_like 'a generatable identifier'

  it_behaves_like 'a normalizable identifier',
                  valid_id: 'DEUTDEFF500',
                  dirty_id: 'DEUT-DE-FF-500',
                  invalid_id: 'INVALID'

  it_behaves_like 'a formattable identifier',
                  valid_id: 'DEUTDEFF500',
                  dirty_id: 'DEUT DE FF 500',
                  invalid_id: 'INVALID'

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'DEUTDEFF500',
                  invalid_length_id: 'DEUTDEFF5',
                  invalid_chars_id: 'DEUTDEF!'

  it_behaves_like 'a validate! identifier',
                  valid_id: 'DEUTDEFF500',
                  invalid_length_id: 'DEUTDEFF5',
                  invalid_chars_id: 'DEUTDEF!'

  # Serialization
  it_behaves_like 'a hashable identifier',
                  valid_id: 'DEUTDEFF500',
                  invalid_id: 'INVALID',
                  expected_type: :bic,
                  expected_components: {
                    bank_code: 'DEUT', country_code: 'DE', location_code: 'FF', branch_code: '500'
                  }

  context 'when BIC11 is valid' do # covers AE1
    let(:bic_code) { 'DEUTDEFF500' }

    it 'parses all components' do
      expect(bic.bank_code).to eq('DEUT')
      expect(bic.country_code).to eq('DE')
      expect(bic.location_code).to eq('FF')
      expect(bic.branch_code).to eq('500')
    end

    it 'is valid' do
      expect(bic.valid?).to be(true)
    end
  end

  context 'when BIC8 is valid' do # covers AE1
    let(:bic_code) { 'DEUTDEFF' }

    it 'parses components with nil branch code' do
      expect(bic.bank_code).to eq('DEUT')
      expect(bic.country_code).to eq('DE')
      expect(bic.location_code).to eq('FF')
      expect(bic.branch_code).to be_nil
    end

    it 'is valid and stays 8 characters when normalized (no XXX padding)' do
      expect(bic.valid?).to be(true)
      expect(bic.normalized).to eq('DEUTDEFF')
    end

    it 'exposes branch_code: nil in #to_h components' do
      expect(bic.to_h[:components]).to eq(
        bank_code: 'DEUT', country_code: 'DE', location_code: 'FF', branch_code: nil
      )
    end
  end

  context 'when BIC has an alphanumeric location code' do
    let(:bic_code) { 'DEUTDE2H' }

    it 'is valid' do
      expect(bic.valid?).to be(true)
      expect(bic.location_code).to eq('2H')
    end
  end

  context 'when BIC11 has a letter-bearing branch code' do
    let(:bic_code) { 'DEUTDEFFA1B' }

    it 'is valid and parses the alphanumeric branch code' do
      expect(bic.valid?).to be(true)
      expect(bic.branch_code).to eq('A1B')
    end
  end

  describe 'value equality' do
    it 'treats normalized-equal BICs as equal and usable as hash keys' do
      a = described_class.new('DEUTDEFF500')
      b = described_class.new('deutdeff500')
      expect(a).to eq(b)
      expect(a).to eql(b)
      expect(a.hash).to eq(b.hash)
      expect({ a => 1 }[b]).to eq(1)
    end
  end

  context 'when BIC is lowercase or separator-dirty' do
    it 'normalizes lowercase input' do
      expect(described_class.new('deutdeff').valid?).to be(true)
      expect(described_class.new('deutdeff').normalized).to eq('DEUTDEFF')
    end

    it 'normalizes hyphen/space-separated input' do
      expect(described_class.normalize('DEUT-DE-FF-500')).to eq('DEUTDEFF500')
      expect(described_class.normalize('DEUT DE FF 500')).to eq('DEUTDEFF500')
    end
  end

  context 'when country code is not recognized' do # covers AE3
    let(:bic_code) { 'DEUTZZFF' }

    it 'is invalid' do
      expect(bic.valid?).to be(false)
    end

    it 'reports an :invalid_country structural error' do
      expect(bic.errors.details.map { |d| d[:error] }).to eq([:invalid_country])
      expect(bic.errors.details.first[:message]).to include("'ZZ'")
    end

    it 'raises InvalidStructureError from validate!' do
      expect { bic.validate! }.to raise_error(SecID::InvalidStructureError, /ZZ/)
    end
  end

  describe '.valid?' do
    it 'returns true for well-formed BICs with recognized countries' do # covers AE3
      %w[DEUTDEFF DEUTDEFF500 BNPAFRPP CHASUS33 NEDSZAJJ HBUKGB4B].each do |code|
        expect(described_class.valid?(code)).to be(true)
      end
    end

    it 'returns false for 9- and 10-character strings (only 8 or 11 accepted)' do # covers AE2
      expect(described_class.valid?('DEUTDEFF5')).to be(false)
      expect(described_class.valid?('DEUTDEFF50')).to be(false)
    end

    it 'reports between-lengths as :invalid_length, not :invalid_format' do # covers AE2
      expect(described_class.new('DEUTDEFF5').errors.details.map { |d| d[:error] }).to eq([:invalid_length])
      expect(described_class.new('DEUTDEFF50').errors.details.map { |d| d[:error] }).to eq([:invalid_length])
    end

    it 'returns false for non-letters in the bank segment' do
      expect(described_class.valid?('DEU1DEFF')).to be(false)
      expect(described_class.new('DEU1DEFF').errors.details.map { |d| d[:error] }).to eq([:invalid_format])
    end

    it 'returns false for non-letters in the country segment' do
      expect(described_class.valid?('DEUT12FF')).to be(false)
      expect(described_class.new('DEUT12FF').errors.details.map { |d| d[:error] }).to eq([:invalid_format])
    end
  end

  describe '.countries' do
    it 'returns a sorted, frozen array including DE and US, excluding ZZ' do
      expect(described_class.countries).to include('DE', 'US', 'XK')
      expect(described_class.countries).not_to include('ZZ')
      expect(described_class.countries).to eq(described_class.countries.sort)
      expect(described_class.countries).to be_frozen
    end

    it 'contains a generated BIC country' do
      expect(described_class.countries).to include(described_class.generate.country_code)
    end
  end

  describe '.generate' do # covers AE4
    it 'produces 8- or 11-character BICs whose country is recognized' do
      (1..250).each do |seed|
        generated = described_class.generate(random: Random.new(seed))
        expect(generated.to_s.length).to(satisfy { |len| [8, 11].include?(len) })
        expect(described_class.countries).to include(generated.country_code)
      end
    end

    it 'produces both BIC8 and BIC11 forms across seeds (branch presence varies)' do
      lengths = (1..250).map { |seed| described_class.generate(random: Random.new(seed)).to_s.length }
      expect(lengths.uniq.sort).to eq([8, 11])
    end
  end
end
