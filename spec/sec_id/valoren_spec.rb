# frozen_string_literal: true

RSpec.describe SecId::Valoren do
  let(:valoren) { described_class.new(valoren_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Core normalization identifier behavior
  it_behaves_like 'a normalization identifier',
                  valid_id: '003886335',
                  unnormalized_id: '3886335',
                  normalized_id: '003886335',
                  invalid_id: '0000'

  context 'when Valoren is valid' do
    let(:valoren_number) { '003886335' }

    it 'parses Valoren correctly' do
      expect(valoren.padding).to eq('00')
      expect(valoren.identifier).to eq('3886335')
      expect(valoren.full_number).to eq(valoren_number)
    end

    describe '#normalize!' do
      it 'returns full Valoren number' do
        expect(valoren.normalize!).to eq(valoren_number)
        expect(valoren.full_number).to eq(valoren_number)
      end
    end

    describe '#to_s' do
      it 'returns the full Valoren number' do
        expect(valoren.to_s).to eq(valoren_number)
      end
    end
  end

  context 'when Valoren is missing leading zeros' do
    let(:valoren_number) { '3886335' }

    it 'parses Valoren correctly' do
      expect(valoren.identifier).to eq(valoren_number)
      expect(valoren.full_number).to eq(valoren_number)
    end

    describe '#normalize!' do
      it 'returns full Valoren number and sets padding' do
        expect(valoren.normalize!).to eq('003886335')
        expect(valoren.full_number).to eq('003886335')
        expect(valoren.padding).to eq('00')
      end
    end

    describe '#to_s' do
      it 'returns the identifier before normalize' do
        expect(valoren.to_s).to eq(valoren_number)
      end

      it 'returns the full number after normalize' do
        valoren.normalize!
        expect(valoren.to_s).to eq('003886335')
      end
    end
  end

  describe '.valid?' do
    context 'when Valoren is malformed' do
      it 'returns false' do
        expect(described_class.valid?('X9')).to be(false)
        expect(described_class.valid?('0000')).to be(false)
        expect(described_class.valid?('0123456789')).to be(false)
      end
    end

    context 'when Valoren is valid' do
      it 'returns true for various valid Valorens' do
        %w[
          3886335 003886335
          24476758 024476758
          35514757 035514757
          97429325 097429325
        ].each do |valoren_number|
          expect(described_class.valid?(valoren_number)).to be(true)
        end
      end
    end
  end

  describe '.normalize!' do
    context 'when Valoren is malformed' do
      it 'raises an error' do
        expect { described_class.normalize!('X9') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.normalize!('0000') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.normalize!('0123456789') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when Valoren is valid' do
      it 'normalizes padding and returns full Valoren number' do
        expect(described_class.normalize!('3886335')).to eq('003886335')
        expect(described_class.normalize!('003886335')).to eq('003886335')
        expect(described_class.normalize!('24476758')).to eq('024476758')
        expect(described_class.normalize!('35514757')).to eq('035514757')
        expect(described_class.normalize!('97429325')).to eq('097429325')
      end
    end
  end

  describe '.valid_format?' do
    context 'when Valoren is malformed' do
      it 'returns false' do
        expect(described_class.valid_format?('X9')).to be(false)
        expect(described_class.valid_format?('0000')).to be(false)
        expect(described_class.valid_format?('0123456789')).to be(false)
      end
    end

    context 'when Valoren is valid or missing leading zeros' do
      it 'returns true' do
        expect(described_class.valid_format?('3886335')).to be(true)
        expect(described_class.valid_format?('003886335')).to be(true)
        expect(described_class.valid_format?('24476758')).to be(true)
        expect(described_class.valid_format?('35514757')).to be(true)
        expect(described_class.valid_format?('97429325')).to be(true)
      end
    end
  end
end
