# frozen_string_literal: true

RSpec.describe SecID::FIGI do
  let(:figi) { described_class.new(figi_number) }

  context 'when FIGI is valid' do
    let(:figi_number) { 'BBG000H4FSM0' }

    it 'parses FIGI correctly' do
      expect(figi.identifier).to eq('BBG000H4FSM')
      expect(figi.prefix).to eq('BB')
      expect(figi.random_part).to eq('000H4FSM')
      expect(figi.check_digit).to eq(0)
    end

    describe '#valid?' do
      it 'returns true' do
        expect(figi.valid?).to be(true)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns full FIGI number' do
        expect(figi.restore!).to eq(figi_number)
        expect(figi.full_number).to eq(figi_number)
      end
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

  context 'when FIGI number is missing check-digit' do
    let(:figi_number) { 'BBG000BLNQ1' }

    it 'parses FIGI correctly' do
      expect(figi.identifier).to eq(figi_number)
      expect(figi.prefix).to eq('BB')
      expect(figi.random_part).to eq('000BLNQ1')
      expect(figi.check_digit).to be_nil
    end

    describe '#valid?' do
      it 'returns false' do
        expect(figi.valid?).to be(false)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns full FIGI number' do
        expect(figi.restore!).to eq('BBG000BLNQ16')
        expect(figi.full_number).to eq('BBG000BLNQ16')
      end
    end
  end

  describe '.valid?' do
    context 'when FIGI is incorrect' do
      it 'returns false' do
        expect(described_class.valid?('US03783315')).to be(false)
        expect(described_class.valid?('US037833104')).to be(false)
        expect(described_class.valid?('US0378331004')).to be(false) # invalid check-digit
        expect(described_class.valid?('US03783315123')).to be(false)
      end
    end

    context 'when FIGI is valid' do
      it 'returns true' do
        %w[KKG000000M81 BBG008B8STT7 BBG00QRVW6J5 BBG001S6RDX9 BBG000CJYWS6].each do |figi_number|
          expect(described_class.valid?(figi_number)).to be(true)
        end
      end
    end
  end

  describe '.restore!' do
    context 'when FIGI is incorrect' do
      it 'raises an error' do
        expect { described_class.restore!('BBG000HY4H') }.to raise_error(SecID::InvalidFormatError)
        expect { described_class.restore!('BBG000HY4HWX') }.to raise_error(SecID::InvalidFormatError)
        expect { described_class.restore!('BBG000HY4HW90') }.to raise_error(SecID::InvalidFormatError)
      end
    end

    context 'when FIGI is valid' do
      it 'restores check-digit and returns full FIGI number' do
        expect(described_class.restore!('BBG000HY4HW')).to eq('BBG000HY4HW9')
        expect(described_class.restore!('BBG000HY4HW9')).to eq('BBG000HY4HW9')
        expect(described_class.restore!('BBG000BCK0D')).to eq('BBG000BCK0D3')
        expect(described_class.restore!('BBG000BCK0D3')).to eq('BBG000BCK0D3')
        expect(described_class.restore!('BBG000BKRK3')).to eq('BBG000BKRK35')
      end
    end
  end

  describe '.valid_format?' do
    context 'when FIGI has a disallowed prefix' do
      it 'returns false' do
        expect(described_class.valid_format?('GGGKFNH88CW')).to be(false)
        expect(described_class.valid_format?('GBGFFK4C9TP')).to be(false)
        expect(described_class.valid_format?('GHGH4FR4J04')).to be(false)
        expect(described_class.valid_format?('KYGLM70ZJQD')).to be(false)
        expect(described_class.valid_format?('VGG19LLVFTH')).to be(false)
      end
    end

    context 'when FIGI is incorrect' do
      it 'returns false' do
        expect(described_class.valid_format?('BBG000HY4H')).to be(false)
        expect(described_class.valid_format?('BB 000HY4HW')).to be(false)
        expect(described_class.valid_format?('BBG000HY4HWX')).to be(false)
        expect(described_class.valid_format?('BBG000HY4HW90')).to be(false)
      end
    end

    context 'when FIGI is valid or missing check-digit' do
      it 'returns true' do
        expect(described_class.valid_format?('BBG000HY4HW')).to be(true)
        expect(described_class.valid_format?('BBG000HY4HW9')).to be(true)
        expect(described_class.valid_format?('BBG000BCK0D')).to be(true)
        expect(described_class.valid_format?('BBG000BCK0D3')).to be(true)
        expect(described_class.valid_format?('BBG000BKRK3')).to be(true)
      end
    end
  end

  describe '.check_digit' do
    context 'when FIGI is incorrect' do
      it 'raises an error' do
        expect { described_class.check_digit('BBG000HY4H') }.to raise_error(SecID::InvalidFormatError)
        expect { described_class.check_digit('BBG000HY4HWX') }.to raise_error(SecID::InvalidFormatError)
        expect { described_class.check_digit('BBG000HY4HW90') }.to raise_error(SecID::InvalidFormatError)
      end
    end

    context 'when FIGI is valid' do
      it 'calculates and returns the check-digit' do
        expect(described_class.check_digit('BBG000HY4HW')).to eq(9)
        expect(described_class.check_digit('BBG000HY4HW9')).to eq(9)
        expect(described_class.check_digit('BBG000BCK0D')).to eq(3)
        expect(described_class.check_digit('BBG000BCK0D3')).to eq(3)
        expect(described_class.check_digit('BBG000BKRK3')).to eq(5)
      end
    end
  end
end
