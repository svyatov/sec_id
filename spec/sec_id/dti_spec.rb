# frozen_string_literal: true

RSpec.describe SecID::DTI do
  let(:dti) { described_class.new(dti_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Digital Token Identifier',
                  id_length: 9,
                  has_checksum: true

  it_behaves_like 'a generatable identifier'

  it_behaves_like 'a normalizable identifier',
                  valid_id: 'X9J9K872S',
                  dirty_id: 'x9-j9k872-s',
                  invalid_id: 'X9J9K872Y'

  it_behaves_like 'a formattable identifier',
                  valid_id: 'X9J9K872S',
                  dirty_id: 'x9-j9k872-s',
                  invalid_id: 'X9J9K872Y'

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'X9J9K872S',
                  invalid_length_id: 'X9J9K87',
                  invalid_chars_id: 'X9J9K872Y'

  it_behaves_like 'a validate! identifier',
                  valid_id: 'X9J9K872S',
                  invalid_length_id: 'X9J9K87',
                  invalid_chars_id: 'X9J9K872Y'

  it_behaves_like 'detects invalid checksum',
                  valid_id: 'X9J9K872S',
                  invalid_checksum_id: 'X9J9K8721'

  it_behaves_like 'validate! detects invalid checksum',
                  invalid_checksum_id: 'X9J9K8721'

  it_behaves_like 'detects invalid format',
                  invalid_format_id: '012345678'

  # Serialization
  it_behaves_like 'a hashable identifier',
                  valid_id: 'X9J9K872S',
                  invalid_id: 'X9J9K872Y',
                  expected_type: :dti,
                  expected_components: { checksum: 'S' }

  # Core checksum identifier behavior
  it_behaves_like 'a checksum identifier',
                  valid_id: 'X9J9K872S',
                  valid_id_without_check: 'X9J9K872',
                  restored_id: 'X9J9K872S',
                  invalid_format_id: '012345678',
                  invalid_checksum_id: 'X9J9K8721',
                  expected_checksum: 'S',
                  expected_checksum_class: String

  context 'when DTI is valid' do
    let(:dti_number) { 'X9J9K872S' }

    it 'parses DTI correctly' do
      expect(dti.identifier).to eq('X9J9K872')
      expect(dti.checksum).to eq('S')
    end
  end

  context 'when DTI number is missing check character' do
    let(:dti_number) { 'X9J9K872' }

    it 'parses DTI correctly' do
      expect(dti.identifier).to eq(dti_number)
      expect(dti.checksum).to be_nil
    end
  end

  describe '.valid?' do
    it 'returns true for verified registry vectors' do
      %w[X9J9K872S JVMWS68W1 ZN227BVRW 993D8X1FB DJ0QPRH0W L09Q657BK
         L6GTZC9G4 20J63Z4N3 820B7G1NL K1NS41N51 523PVPHKS 10ZW1X3N5].each do |dti_number|
        expect(described_class.valid?(dti_number)).to be(true)
      end
    end

    it 'accepts numeric input, judged on its digits' do
      expect(described_class.valid?(123_456_789)).to be(false)
    end

    it 'is case-insensitive' do
      expect(described_class.valid?('x9j9k872s')).to be(true)
    end
  end

  describe '.restore' do
    it 'restores check character for various DTIs' do
      expect(described_class.restore('X9J9K872')).to eq('X9J9K872S')
      expect(described_class.restore('JVMWS68W')).to eq('JVMWS68W1')
      expect(described_class.restore('10ZW1X3N')).to eq('10ZW1X3N5')
    end

    it 'pins the algorithm\'s zero-normalization step (s = 30 if s.zero?)' do
      # Synthetic base (not a registry vector) chosen because it drives the running
      # permutation to exactly 0 mid-computation, the one point where the ISO 7064
      # hybrid MOD 31,30 algorithm departs from a plain modulo.
      expect(described_class.restore('BWWHGZZG')).to eq('BWWHGZZG7')
    end
  end

  describe '#errors' do
    context 'when the base starts with 0' do
      it 'returns :invalid_format' do
        result = described_class.new('012345678').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_format])
      end
    end

    context 'when length is 7 (too short)' do
      it 'returns :invalid_length' do
        result = described_class.new('X9J9K87').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_length])
      end
    end

    context 'when length is 10 (too long)' do
      it 'returns :invalid_length' do
        result = described_class.new('X9J9K872SS').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_length])
      end
    end

    context 'when a vowel is present' do
      it 'returns :invalid_characters' do
        result = described_class.new('X9J9K872A').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_characters])
      end
    end

    context "when 'Y' is present" do
      it 'returns :invalid_characters' do
        result = described_class.new('X9J9K872Y').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_characters])
      end
    end
  end

  describe 'Bitcoin grandfathered code' do
    it 'validates the registered code via the exception map' do
      expect(described_class.valid?('4H95J0R2X')).to be(true)
    end

    it 'restores to the registered code, not the algorithmic one' do
      expect(described_class.restore('4H95J0R2')).to eq('4H95J0R2X')
    end

    it 'rejects the algorithmic form as invalid' do
      expect(described_class.valid?('4H95J0R2T')).to be(false)
      expect(described_class.new('4H95J0R2T').errors.details.map { |d| d[:error] }).to eq([:invalid_checksum])
    end

    it 'agrees across #checksum and #restore!' do
      instance = described_class.new('4H95J0R2')
      expect(instance.calculate_checksum).to eq('X')
      expect(instance.restore!.to_s).to eq('4H95J0R2X')
      expect(instance.checksum).to eq('X')
    end
  end

  describe 'GRANDFATHERED_CODES invariants' do
    described_class::GRANDFATHERED_CODES.each do |base, registered_code|
      it "'#{base}' is a valid 8-character base" do
        expect(base).to match(/\A[1-9B-DF-HJ-NP-TV-XZ][0-9B-DF-HJ-NP-TV-XZ]{7}\z/)
      end

      it "'#{registered_code}' is the base plus one alphabet character" do
        expect(registered_code).to eq("#{base}#{registered_code[-1]}")
        expect(registered_code.length).to eq(9)
      end

      it "'#{base}' differs from its algorithmic check character (otherwise it's not an exception)" do
        algorithmic = described_class.new(base).send(:iso7064_mod31_30_check_char, base)
        expect(registered_code[-1]).not_to eq(algorithmic)
      end
    end
  end

  describe '.generate' do
    it 'never produces a vowel, Y, or a leading zero, across many seeds' do
      (1..250).each do |seed|
        generated = described_class.generate(random: Random.new(seed))
        expect(generated.identifier).to match(/\A[1-9B-DF-HJ-NP-TV-XZ][0-9B-DF-HJ-NP-TV-XZ]{7}\z/)
        expect(generated).to be_valid
      end
    end
  end
end
