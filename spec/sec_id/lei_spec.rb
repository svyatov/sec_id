# frozen_string_literal: true

RSpec.describe SecId::LEI do
  let(:lei) { described_class.new(lei_number) }

  context 'when LEI is valid' do
    let(:lei_number) { '5493006MHB84DD0ZWV18' }

    it 'parses LEI correctly' do
      expect(lei.identifier).to eq('5493006MHB84DD0ZWV')
      expect(lei.lou_id).to eq('5493')
      expect(lei.reserved).to eq('00')
      expect(lei.entity_id).to eq('6MHB84DD0ZWV')
      expect(lei.check_digit).to eq(18)
    end

    describe '#valid?' do
      it 'returns true' do
        expect(lei.valid?).to be(true)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns full LEI' do
        expect(lei.restore!).to eq(lei_number)
        expect(lei.full_number).to eq(lei_number)
      end
    end

    describe '#to_s' do
      it 'returns full LEI' do
        expect(lei.to_s).to eq(lei_number)
      end
    end
  end

  context 'when LEI has invalid check-digit' do
    let(:lei_number) { '5493006MHB84DD0ZWV99' }

    it 'parses LEI correctly' do
      expect(lei.identifier).to eq('5493006MHB84DD0ZWV')
      expect(lei.check_digit).to eq(99)
    end

    describe '#valid?' do
      it 'returns false' do
        expect(lei.valid?).to be(false)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns corrected LEI' do
        expect(lei.restore!).to eq('5493006MHB84DD0ZWV18')
        expect(lei.full_number).to eq('5493006MHB84DD0ZWV18')
      end
    end
  end

  context 'when LEI is missing check-digit' do
    let(:lei_number) { '5493006MHB84DD0ZWV' }

    it 'parses LEI correctly' do
      expect(lei.identifier).to eq(lei_number)
      expect(lei.lou_id).to eq('5493')
      expect(lei.reserved).to eq('00')
      expect(lei.entity_id).to eq('6MHB84DD0ZWV')
      expect(lei.check_digit).to be_nil
    end

    describe '#valid?' do
      it 'returns false' do
        expect(lei.valid?).to be(false)
      end
    end

    describe '#restore!' do
      it 'restores check-digit and returns full LEI' do
        expect(lei.restore!).to eq('5493006MHB84DD0ZWV18')
        expect(lei.full_number).to eq('5493006MHB84DD0ZWV18')
      end
    end
  end

  context 'when LEI has all-letter LOU identifier' do
    let(:lei_number) { 'HWUPKR0MPOU8FGXBT394' }

    it 'parses LEI correctly' do
      expect(lei.identifier).to eq('HWUPKR0MPOU8FGXBT3')
      expect(lei.lou_id).to eq('HWUP')
      expect(lei.reserved).to eq('KR')
      expect(lei.entity_id).to eq('0MPOU8FGXBT3')
      expect(lei.check_digit).to eq(94)
    end

    describe '#valid?' do
      it 'returns true' do
        expect(lei.valid?).to be(true)
      end
    end

    describe '#to_s' do
      it 'returns full LEI' do
        expect(lei.to_s).to eq(lei_number)
      end
    end
  end

  context 'when LEI format is invalid' do
    let(:lei_number) { 'INVALID' }

    it 'parses LEI as nil' do
      expect(lei.identifier).to be_nil
      expect(lei.lou_id).to be_nil
      expect(lei.reserved).to be_nil
      expect(lei.entity_id).to be_nil
      expect(lei.check_digit).to be_nil
    end

    describe '#valid?' do
      it 'returns false' do
        expect(lei.valid?).to be(false)
      end
    end

    describe '#restore!' do
      it 'raises an error' do
        expect { lei.restore! }.to raise_error(SecId::InvalidFormatError)
      end
    end
  end

  context 'when LEI contains lowercase letters' do
    let(:lei_number) { '5493006mhb84dd0zwv18' }

    it 'normalizes to uppercase and parses correctly' do
      expect(lei.identifier).to eq('5493006MHB84DD0ZWV')
      expect(lei.valid?).to be(true)
    end
  end

  describe '.valid?' do
    context 'when LEI is incorrect' do
      it 'returns false' do
        expect(described_class.valid?('INVALID')).to be(false)
        expect(described_class.valid?('5493006MHB84DD0ZWV')).to be(false) # missing check-digit
        expect(described_class.valid?('5493006MHB84DD0ZWV99')).to be(false) # wrong check-digit
        expect(described_class.valid?('5493006MHB84DD0ZWV1')).to be(false) # too short
        expect(described_class.valid?('5493006MHB84DD0ZWV123')).to be(false) # too long
      end
    end

    context 'when LEI is valid' do
      it 'returns true' do
        # Real-world LEI examples
        expect(described_class.valid?('5493006MHB84DD0ZWV18')).to be(true)
        expect(described_class.valid?('529900T8BM49AURSDO55')).to be(true)
        expect(described_class.valid?('HWUPKR0MPOU8FGXBT394')).to be(true)
        expect(described_class.valid?('7ZW8QJWVPR4P1J1KQY45')).to be(true)
        expect(described_class.valid?('549300TRUWO2CD2G5692')).to be(true)
      end
    end
  end

  describe '.valid_format?' do
    context 'when LEI format is incorrect' do
      it 'returns false' do
        expect(described_class.valid_format?('INVALID')).to be(false)
        expect(described_class.valid_format?('5493006MHB84DD0ZWV1')).to be(false) # too short
        expect(described_class.valid_format?('5493006MHB84DD0ZWV123')).to be(false) # too long
        expect(described_class.valid_format?('5493006MHB84DD0ZWV!!')).to be(false) # invalid chars
      end
    end

    context 'when LEI format is valid (with or without check-digit)' do
      it 'returns true' do
        expect(described_class.valid_format?('5493006MHB84DD0ZWV18')).to be(true)
        expect(described_class.valid_format?('5493006MHB84DD0ZWV')).to be(true) # missing check-digit
        expect(described_class.valid_format?('5493006MHB84DD0ZWV99')).to be(true) # wrong check-digit but valid format
      end
    end
  end

  describe '.restore!' do
    context 'when LEI format is incorrect' do
      it 'raises an error' do
        expect { described_class.restore!('INVALID') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.restore!('5493006MHB84DD0ZWV1') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when LEI format is valid' do
      it 'restores check-digit and returns full LEI' do
        expect(described_class.restore!('5493006MHB84DD0ZWV')).to eq('5493006MHB84DD0ZWV18')
        expect(described_class.restore!('5493006MHB84DD0ZWV99')).to eq('5493006MHB84DD0ZWV18')
        expect(described_class.restore!('529900T8BM49AURSDO')).to eq('529900T8BM49AURSDO55')
        expect(described_class.restore!('HWUPKR0MPOU8FGXBT3')).to eq('HWUPKR0MPOU8FGXBT394')
      end
    end
  end

  describe '.check_digit' do
    context 'when LEI format is incorrect' do
      it 'raises an error' do
        expect { described_class.check_digit('INVALID') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.check_digit('5493006MHB84DD0ZWV1') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when LEI format is valid' do
      it 'calculates and returns the check-digit' do
        expect(described_class.check_digit('5493006MHB84DD0ZWV')).to eq(18)
        expect(described_class.check_digit('5493006MHB84DD0ZWV18')).to eq(18)
        expect(described_class.check_digit('529900T8BM49AURSDO')).to eq(55)
        expect(described_class.check_digit('HWUPKR0MPOU8FGXBT3')).to eq(94)
        expect(described_class.check_digit('7ZW8QJWVPR4P1J1KQY')).to eq(45)
      end
    end
  end
end
