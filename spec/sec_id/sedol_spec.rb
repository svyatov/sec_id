# frozen_string_literal: true

RSpec.describe SecId::SEDOL do
  let(:sedol) { described_class.new(sedol_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  context 'when SEDOL is valid' do
    let(:sedol_number) { 'B19GKT4' }

    it 'parses SEDOL correctly' do
      expect(sedol.identifier).to eq('B19GKT')
      expect(sedol.check_digit).to eq(4)
    end

    describe '#valid?' do
      it 'returns true' do
        expect(sedol.valid?).to be(true)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns full SEDOL number' do
        expect(sedol.restore!).to eq(sedol_number)
        expect(sedol.full_number).to eq(sedol_number)
      end
    end
  end

  context 'when SEDOL number is missing check-digit' do
    let(:sedol_number) { '552902' }

    it 'parses SEDOL number correctly' do
      expect(sedol.identifier).to eq(sedol_number)
      expect(sedol.check_digit).to be_nil
    end

    describe '#valid?' do
      it 'returns false' do
        expect(sedol.valid?).to be(false)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns full SEDOL number' do
        expect(sedol.restore!).to eq('5529027')
        expect(sedol.full_number).to eq('5529027')
      end
    end
  end

  describe '.valid?' do
    context 'when SEDOL is incorrect' do
      it 'returns false' do
        expect(described_class.valid?('A61351')).to be(false)
        expect(described_class.valid?('6135118')).to be(false) # invalid check-digit
        expect(described_class.valid?('61351115')).to be(false)
      end
    end

    context 'when SEDOL is valid' do
      it 'returns true' do
        %w[
          2307389 5529027 B03MLX2 B0Z52W5 B19GKT4 6135111
        ].each do |sedol_number|
          expect(described_class.valid?(sedol_number)).to be(true)
        end
      end
    end
  end

  describe '.restore!' do
    context 'when SEDOL is incorrect' do
      it 'raises an error' do
        expect { described_class.restore!('I09CB4') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.restore!('B09CBL40') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when SEDOL is valid' do
      it 'restores check-digit and returns full SEDOL number' do
        expect(described_class.restore!('B09CBL')).to eq('B09CBL4')
        expect(described_class.restore!('219071')).to eq('2190716')
        expect(described_class.restore!('B923455')).to eq('B923452')
        expect(described_class.restore!('B99876')).to eq('B998762')
        expect(described_class.restore!('2307380')).to eq('2307389')
      end
    end
  end

  describe '.valid_format?' do
    context 'when SEDOL is incorrect' do
      it 'returns false' do
        expect(described_class.valid_format?('E23073')).to be(false)
        expect(described_class.valid_format?('23073894')).to be(false)
      end
    end

    context 'when SEDOL is valid or missing check-digit' do
      it 'returns true' do
        expect(described_class.valid_format?('B09CBL4')).to be(true)
        expect(described_class.valid_format?('219071')).to be(true)
        expect(described_class.valid_format?('B923452')).to be(true)
        expect(described_class.valid_format?('B99876')).to be(true)
        expect(described_class.valid_format?('2307389')).to be(true)
      end
    end
  end

  describe '.check_digit' do
    context 'when SEDOL is incorrect' do
      it 'raises an error' do
        expect { described_class.check_digit('55U290') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.check_digit('55290275') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when SEDOL is valid' do
      it 'calculates and returns the check-digit' do
        expect(described_class.check_digit('554389')).to eq(0)
        expect(described_class.check_digit('2190716')).to eq(6)
        expect(described_class.check_digit('B0Z52W')).to eq(5)
        expect(described_class.check_digit('B19GKT4')).to eq(4)
        expect(described_class.check_digit('613511')).to eq(1)
      end
    end
  end
end
