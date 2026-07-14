# frozen_string_literal: true

RSpec.describe SecID::UPI do
  let(:upi) { described_class.new(upi_number) }

  # DSB-issued UPI vectors from "The UPI: How to search for and create a UPI"
  # (ANNA-DSB, Oct 2023). Clean vectors are used verbatim; OCR-corrected vectors
  # note the single-character fix repairing a PDF-OCR confusion. Maps each UPI to
  # its check character.
  let(:vectors) do
    {
      'QZRBG6ZTKS42' => '2', # clean
      'QZT6XRWJ7Z2D' => 'D', # clean
      'QZM174M4JG8F' => 'F', # clean
      'QZT7L05N7HG3' => '3', # clean
      'QZXKR05S3DL1' => '1', # OCR-corrected: S<-5
      'QZZBWXD9QW48' => '8', # OCR-corrected: S<-5
      'QZNBH7B2BQ52' => '2'  # OCR-corrected: B<-8
    }
  end

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Unique Product Identifier',
                  id_length: 12,
                  has_checksum: true

  it_behaves_like 'a generatable identifier'

  it_behaves_like 'a normalizable identifier',
                  valid_id: 'QZRBG6ZTKS42',
                  dirty_id: 'qz-rbg6ztks-42',
                  invalid_id: 'QZRBG6ZTKS43'

  it_behaves_like 'a formattable identifier',
                  valid_id: 'QZRBG6ZTKS42',
                  dirty_id: 'qz-rbg6ztks-42',
                  invalid_id: 'QZRBG6ZTKS43'

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'QZRBG6ZTKS42',
                  invalid_length_id: 'QZRBG6ZTK4',
                  invalid_chars_id: 'QZABG6ZTKS42'

  it_behaves_like 'a validate! identifier',
                  valid_id: 'QZRBG6ZTKS42',
                  invalid_length_id: 'QZRBG6ZTK4',
                  invalid_chars_id: 'QZABG6ZTKS42'

  it_behaves_like 'detects invalid checksum',
                  valid_id: 'QZRBG6ZTKS42',
                  invalid_checksum_id: 'QZRBG6ZTKS43'

  it_behaves_like 'validate! detects invalid checksum',
                  invalid_checksum_id: 'QZRBG6ZTKS43'

  it_behaves_like 'detects invalid format',
                  invalid_format_id: 'RBG6ZTKS42QZ'

  # Serialization
  it_behaves_like 'a hashable identifier',
                  valid_id: 'QZRBG6ZTKS42',
                  invalid_id: 'QZRBG6ZTKS43',
                  expected_type: :upi,
                  expected_components: { checksum: '2', check_digit: '2' }

  # Core checksum identifier behavior
  it_behaves_like 'a checksum identifier',
                  valid_id: 'QZRBG6ZTKS42',
                  valid_id_without_check: 'QZRBG6ZTKS4',
                  restored_id: 'QZRBG6ZTKS42',
                  invalid_format_id: 'RBG6ZTKS42QZ',
                  invalid_checksum_id: 'QZRBG6ZTKS43',
                  expected_checksum: '2',
                  expected_checksum_class: String

  describe '.valid?' do
    it 'returns true for every DSB-issued vector' do
      vectors.each_key do |vector|
        expect(described_class.valid?(vector)).to be(true)
      end
    end

    it 'computes the expected String check character for every vector' do
      vectors.each do |vector, check|
        instance = described_class.new(vector)
        expect(instance.checksum).to eq(check)
        expect(instance.calculate_checksum).to eq(check)
      end
    end

    it 'accepts lowercase and surrounding whitespace' do
      expect(described_class.valid?(' qzrbg6ztks42 ')).to be(true)
      expect(described_class.valid?('qzrbg6ztks42')).to be(true)
    end
  end

  describe '.restore' do
    it 'restores the check character' do
      expect(described_class.restore('QZRBG6ZTKS4')).to eq('QZRBG6ZTKS42')
    end

    it 'mutates and returns self for #restore!' do
      instance = described_class.new('QZRBG6ZTKS4')
      expect(instance.restore!).to equal(instance)
      expect(instance.to_s).to eq('QZRBG6ZTKS42')
      expect(instance.checksum).to eq('2')
    end
  end

  describe 'parsing' do
    context 'when UPI is valid' do
      let(:upi_number) { 'QZRBG6ZTKS42' }

      it 'parses the identifier and check character' do
        expect(upi.identifier).to eq('QZRBG6ZTKS4')
        expect(upi.checksum).to eq('2')
      end
    end

    context 'when UPI is missing the check character' do
      let(:upi_number) { 'QZRBG6ZTKS4' }

      it 'is format-valid (check character optional) but invalid overall' do
        expect(upi.identifier).to eq(upi_number)
        expect(upi.checksum).to be_nil
        expect(upi.errors.details.map { |d| d[:error] }).to eq([:invalid_checksum])
      end
    end

    context 'when components/to_h/deconstruct_keys expose the check character' do
      let(:upi_number) { 'QZRBG6ZTKS42' }

      it 'destructures via case/in' do
        upi => { checksum: }
        expect(checksum).to eq('2')
        expect(upi.to_h[:components]).to eq({ checksum: '2', check_digit: '2' })
      end
    end
  end

  describe '#errors' do
    context 'when length is 10 (too short)' do
      it 'returns :invalid_length with the drift-catching message' do
        result = described_class.new('QZRBG6ZTK4').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_length])
        expect(result.details.first[:message]).to eq('Expected 12 characters, got 10')
      end
    end

    context 'when length is 13 (too long)' do
      it 'returns :invalid_length with the drift-catching message' do
        result = described_class.new('QZRBG6ZTKS422').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_length])
        expect(result.details.first[:message]).to eq('Expected 12 characters, got 13')
      end
    end

    context 'when a vowel is present' do
      it 'returns :invalid_characters' do
        result = described_class.new('QZABG6ZTKS42').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_characters])
      end
    end

    context "when 'Y' is present in the body" do
      it 'returns :invalid_characters' do
        result = described_class.new('QZRBG6ZTKY42').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_characters])
      end
    end

    context 'when the QZ prefix is missing' do
      it 'returns :invalid_format' do
        result = described_class.new('RBG6ZTKS42QZ').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_format])
      end
    end
  end

  describe '.generate' do
    it 'produces valid, QZ-prefixed codes across 100 seeds' do
      (1..100).each do |seed|
        generated = described_class.generate(random: Random.new(seed))
        expect(generated).to be_valid
        expect(generated.to_s).to start_with('QZ')
        expect(generated.to_s).to match(described_class::VALID_CHARS_REGEX)
      end
    end

    it 'is deterministic for a fixed seed' do
      expect(described_class.generate(random: Random.new(42)).to_s).to eq('QZ6MXGB7XN66')
    end
  end
end
