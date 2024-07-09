# frozen_string_literal: true

RSpec.describe SecId::ISIN do
  let(:isin) { described_class.new(isin_number) }

  context 'when ISIN is valid' do
    let(:isin_number) { 'IE00B296YR77' }

    it 'parses ISIN correctly' do
      expect(isin.identifier).to eq('IE00B296YR7')
      expect(isin.country_code).to eq('IE')
      expect(isin.nsin).to eq('00B296YR7')
      expect(isin.check_digit).to eq(7)
    end

    describe '#valid?' do
      it 'returns true' do
        expect(isin.valid?).to be(true)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns full ISIN number' do
        expect(isin.restore!).to eq(isin_number)
        expect(isin.full_number).to eq(isin_number)
      end
    end
  end

  context 'when ISIN is missing country code' do
    let(:isin_number) { '00B296YR77' }

    it 'parses ISIN correctly' do
      expect(isin.identifier).to be_nil
      expect(isin.country_code).to be_nil
      expect(isin.nsin).to be_nil
      expect(isin.check_digit).to be_nil
    end

    describe '#valid?' do
      it 'returns false' do
        expect(isin.valid?).to be(false)
      end
    end

    describe '#restore!' do
      it 'raises an error' do
        expect { isin.restore! }.to raise_error(SecId::InvalidFormatError)
      end
    end
  end

  context 'when ISIN number is missing check-digit' do
    let(:isin_number) { 'IE00B296YR7' }

    it 'parses ISIN number correctly' do
      expect(isin.identifier).to eq(isin_number)
      expect(isin.country_code).to eq('IE')
      expect(isin.nsin).to eq('00B296YR7')
      expect(isin.check_digit).to be_nil
    end

    describe '#valid?' do
      it 'returns false' do
        expect(isin.valid?).to be(false)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns full ISIN number' do
        expect(isin.restore!).to eq('IE00B296YR77')
        expect(isin.full_number).to eq('IE00B296YR77')
      end
    end
  end

  describe '.valid?' do
    context 'when ISIN is incorrect' do
      it 'returns false' do
        expect(described_class.valid?('US03783315')).to be(false)
        expect(described_class.valid?('US037833104')).to be(false)
        expect(described_class.valid?('US0378331004')).to be(false) # invalid check-digit
        expect(described_class.valid?('US03783315123')).to be(false)
      end
    end

    context 'when ISIN is valid' do
      it 'returns true' do
        %w[
          US5949181045 US38259P5089 US0378331005 NL0000729408 JP3946600008
          DE000DZ21632 DE000DB7HWY7 DE000CM7VX13 CH0031240127 CA9861913023
        ].each do |isin_number|
          expect(described_class.valid?(isin_number)).to be(true)
        end

        expect(described_class.valid?('AU0000XVGZA3')).to be(true)
        expect(described_class.valid?('AU0000VXGZA3')).to be(true) # it's not a typo, it's a check-digit flaw in ISIN
      end
    end
  end

  describe '.restore!' do
    context 'when ISIN is incorrect' do
      it 'raises an error' do
        expect { described_class.restore!('US03783315') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.restore!('US03783315123') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when ISIN is valid' do
      it 'restores check-digit and returns full ISIN number' do
        expect(described_class.restore!('AU0000XVGZA')).to eq('AU0000XVGZA3')
        expect(described_class.restore!('AU0000VXGZA7')).to eq('AU0000VXGZA3')
        expect(described_class.restore!('GB000263494')).to eq('GB0002634946')
        expect(described_class.restore!('US037833104')).to eq('US0378331047')
        expect(described_class.restore!('US0378331004')).to eq('US0378331005')
      end
    end
  end

  describe '.valid_format?' do
    context 'when ISIN is incorrect' do
      it 'returns false' do
        expect(described_class.valid_format?('US03783315')).to be(false)
        expect(described_class.valid_format?('US03783315123')).to be(false)
      end
    end

    context 'when ISIN is valid or missing check-digit' do
      it 'returns true' do
        expect(described_class.valid_format?('AU0000XVGZA')).to be(true)
        expect(described_class.valid_format?('AU0000VXGZA7')).to be(true)
        expect(described_class.valid_format?('GB000263494')).to be(true)
        expect(described_class.valid_format?('US037833104')).to be(true)
        expect(described_class.valid_format?('US0378331004')).to be(true)
      end
    end
  end

  describe '.check_digit' do
    context 'when ISIN is incorrect' do
      it 'raises an error' do
        expect { described_class.check_digit('US03783315') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.check_digit('US03783315123') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when ISIN is valid' do
      it 'calculates and returns the check-digit' do
        expect(described_class.check_digit('AU0000XVGZA')).to eq(3)
        expect(described_class.check_digit('AU0000VXGZA7')).to eq(3)
        expect(described_class.check_digit('GB000263494')).to eq(6)
        expect(described_class.check_digit('US037833104')).to eq(7)
        expect(described_class.check_digit('US0378331004')).to eq(5)
      end
    end
  end
end
