# frozen_string_literal: true

RSpec.describe SecId::CIK do
  let(:cik) { described_class.new(cik_number) }

  context 'when CIK is valid' do
    let(:cik_number) { '0001521365' }

    it 'parses CIK correctly' do
      expect(cik.padding).to eq('000')
      expect(cik.identifier).to eq('1521365')
      expect(cik.full_number).to eq(cik_number)
    end

    describe '#valid?' do
      it 'returns true' do
        expect(cik.valid?).to be(true)
      end
    end

    describe '#normalize!' do
      it 'returns full CIK number' do
        expect(cik.normalize!).to eq(cik_number)
        expect(cik.full_number).to eq(cik_number)
      end
    end

    describe '#to_s' do
      it 'returns the full CIK number' do
        expect(cik.to_s).to eq(cik_number)
      end
    end
  end

  context 'when CIK number is missing leading zeros' do
    let(:cik_number) { '10624' }

    it 'parses CIK number correctly' do
      expect(cik.identifier).to eq(cik_number)
      expect(cik.full_number).to eq(cik_number)
    end

    describe '#valid?' do
      it 'returns true' do
        expect(cik.valid?).to be(true)
      end
    end

    describe '#normalize!' do
      it 'returns full CIK number and sets padding' do
        expect(cik.normalize!).to eq('0000010624')
        expect(cik.full_number).to eq('0000010624')
        expect(cik.padding).to eq('00000')
      end
    end

    describe '#to_s' do
      it 'returns the identifier before normalize' do
        expect(cik.to_s).to eq(cik_number)
      end

      it 'returns the full number after normalize' do
        cik.normalize!
        expect(cik.to_s).to eq('0000010624')
      end
    end
  end

  describe '.valid?' do
    context 'when CIK is malformed' do
      it 'returns false' do
        expect(described_class.valid?('X9')).to be(false)
        expect(described_class.valid?('0000000000')).to be(false)
        expect(described_class.valid?('01234567890')).to be(false)
      end
    end

    context 'when CIK is valid' do
      it 'returns true' do
        %w[0000000003 0000089562 0000010624 0002035979].each do |cik_number|
          expect(described_class.valid?(cik_number)).to be(true)
        end
      end
    end
  end

  describe '.normalize!' do
    context 'when CIK is malformed' do
      it 'raises an error' do
        expect { described_class.normalize!('X9') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.normalize!('0000000000') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.normalize!('09876543210') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when CIK is valid' do
      it 'normalizes padding and returns full CIK number' do
        expect(described_class.normalize!('3')).to eq('0000000003')
        expect(described_class.normalize!('0000000003')).to eq('0000000003')
        expect(described_class.normalize!('1072424')).to eq('0001072424')
        expect(described_class.normalize!('001072424')).to eq('0001072424')
        expect(described_class.normalize!('0001072424')).to eq('0001072424')
      end
    end
  end

  describe '.valid_format?' do
    context 'when CIK is malformed' do
      it 'returns false' do
        expect(described_class.valid_format?('X9')).to be(false)
        expect(described_class.valid_format?('0000000000')).to be(false)
        expect(described_class.valid_format?('01234567890')).to be(false)
      end
    end

    context 'when CIK is valid or missing leading zeros' do
      it 'returns true' do
        expect(described_class.valid_format?('3')).to be(true)
        expect(described_class.valid_format?('0000000003')).to be(true)
        expect(described_class.valid_format?('1072424')).to be(true)
        expect(described_class.valid_format?('001072424')).to be(true)
        expect(described_class.valid_format?('0001072424')).to be(true)
      end
    end
  end
end
