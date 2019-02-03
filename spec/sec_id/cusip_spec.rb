# frozen_string_literal: true

RSpec.describe SecId::CUSIP do
  let(:cusip) { described_class.new(cusip_number) }

  context 'when CUSIP is valid' do
    let(:cusip_number) { '68389X105' }

    it 'parses CUSIP correctly' do
      expect(cusip.identifier).to eq('68389X10')
      expect(cusip.cusip6).to eq('68389X')
      expect(cusip.issue).to eq('10')
      expect(cusip.check_digit).to eq(5)
    end

    describe '#valid?' do
      it 'returns true' do
        expect(cusip.valid?).to eq(true)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns full CUSIP number' do
        expect(cusip.restore!).to eq(cusip_number)
        expect(cusip.cusip).to eq(cusip_number)
      end
    end
  end

  context 'when CUSIP number is missing check-digit' do
    let(:cusip_number) { '38259P50' }

    it 'parses CUSIP number correctly' do
      expect(cusip.identifier).to eq(cusip_number)
      expect(cusip.cusip6).to eq('38259P')
      expect(cusip.issue).to eq('50')
      expect(cusip.check_digit).to be_nil
    end

    describe '#valid?' do
      it 'returns false' do
        expect(cusip.valid?).to eq(false)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns full CUSIP number' do
        expect(cusip.restore!).to eq('38259P508')
        expect(cusip.cusip).to eq('38259P508')
      end
    end
  end

  describe '.valid?' do
    context 'when CUSIP is incorrect' do
      it 'returns false' do
        expect(described_class.valid?('5949181')).to eq(false)
        expect(described_class.valid?('594918105')).to eq(false) # invalid check-digit
        expect(described_class.valid?('5949181045')).to eq(false)
      end
    end

    context 'when CUSIP is valid' do
      it 'returns true' do
        %w[
          594918104 38259P508 037833100 17275R102 68389X105 986191302
        ].each do |cusip_number|
          expect(described_class.valid?(cusip_number)).to eq(true)
        end
      end
    end
  end

  describe '.restore!' do
    context 'when CUSIP is incorrect' do
      it 'raises an error' do
        expect { described_class.restore!('68389X1') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.restore!('68389X1055') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when CUSIP is valid' do
      it 'restores check-digit and returns full CUSIP number' do
        expect(described_class.restore!('03783310')).to eq('037833100')
        expect(described_class.restore!('17275R10')).to eq('17275R102')
        expect(described_class.restore!('38259P50')).to eq('38259P508')
        expect(described_class.restore!('59491810')).to eq('594918104')
        expect(described_class.restore!('68389X10')).to eq('68389X105')
      end
    end
  end

  describe '.valid_format?' do
    context 'when CUSIP is incorrect' do
      it 'returns false' do
        expect(described_class.valid_format?('0378331')).to eq(false)
        expect(described_class.valid_format?('0378331009')).to eq(false)
      end
    end

    context 'when CUSIP is valid or missing check-digit' do
      it 'returns true' do
        expect(described_class.valid_format?('38259P50')).to eq(true)
        expect(described_class.valid_format?('38259P508')).to eq(true)
        expect(described_class.valid_format?('68389X10')).to eq(true)
        expect(described_class.valid_format?('68389X105')).to eq(true)
        expect(described_class.valid_format?('986191302')).to eq(true)
      end
    end
  end

  describe '.check_digit' do
    context 'when CUSIP is incorrect' do
      it 'raises an error' do
        expect { described_class.check_digit('9861913') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.check_digit('9861913025') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when CUSIP is valid' do
      it 'calculates and returns the check-digit' do
        expect(described_class.check_digit('03783310')).to eq(0)
        expect(described_class.check_digit('17275R10')).to eq(2)
        expect(described_class.check_digit('38259P50')).to eq(8)
        expect(described_class.check_digit('59491810')).to eq(4)
        expect(described_class.check_digit('68389X10')).to eq(5)
      end
    end
  end
end
