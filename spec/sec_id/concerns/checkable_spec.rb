# frozen_string_literal: true

# Test class for Checkable concern - defined outside RSpec block to avoid redefinition
module CheckableSpecHelper
  class TestClass < SecId::Base
    include SecId::Checkable

    ID_REGEX = /\A(?<identifier>[A-Z]{3})(?<check_digit>\d)?\z/

    def initialize(id) # rubocop:disable Lint/MissingSuper
      parts = parse(id)
      @identifier = parts[:identifier]
      @check_digit = parts[:check_digit]&.to_i
    end

    def calculate_check_digit
      validate_format_for_calculation!
      # Simple algorithm: sum of char positions mod 10
      mod10(identifier.chars.sum { |c| c.ord - 'A'.ord })
    end
  end

  # Test class that doesn't implement calculate_check_digit
  class IncompleteClass < SecId::Base
    include SecId::Checkable

    ID_REGEX = /\A(?<identifier>[A-Z]{3})(?<check_digit>\d)?\z/

    def initialize(id) # rubocop:disable Lint/MissingSuper
      parts = parse(id)
      @identifier = parts[:identifier]
      @check_digit = parts[:check_digit]&.to_i
    end
  end
end

RSpec.describe SecId::Checkable do
  let(:test_class) { CheckableSpecHelper::TestClass }

  describe 'when included in a class' do
    it 'adds check_digit attr_reader' do
      instance = test_class.new('ABC')
      expect(instance).to respond_to(:check_digit)
    end

    it 'adds class methods' do
      expect(test_class).to respond_to(:restore)
      expect(test_class).to respond_to(:restore!)
      expect(test_class).to respond_to(:check_digit)
    end
  end

  describe '#valid?' do
    context 'when check digit is correct' do
      it 'returns true' do
        # A=0, B=1, C=2, sum=3, mod10(10-3)=7
        instance = test_class.new('ABC7')
        expect(instance.valid?).to be(true)
      end
    end

    context 'when check digit is incorrect' do
      it 'returns false' do
        instance = test_class.new('ABC0')
        expect(instance.valid?).to be(false)
      end
    end

    context 'when check digit is missing' do
      it 'returns false' do
        instance = test_class.new('ABC')
        expect(instance.valid?).to be(false)
      end
    end

    context 'when format is invalid' do
      it 'returns false' do
        instance = test_class.new('INVALID')
        expect(instance.valid?).to be(false)
      end
    end
  end

  describe '#restore' do
    it 'returns the full identifier string with correct check digit' do
      instance = test_class.new('ABC')
      expect(instance.restore).to eq('ABC7')
    end

    it 'does not mutate check_digit' do
      instance = test_class.new('ABC')
      instance.restore
      expect(instance.check_digit).to be_nil
    end

    it 'does not mutate full_number' do
      instance = test_class.new('ABC')
      instance.restore
      expect(instance.full_number).to eq('ABC')
    end

    context 'when format is invalid' do
      it 'raises InvalidFormatError' do
        instance = test_class.new('INVALID')
        expect { instance.restore }.to raise_error(SecId::InvalidFormatError)
      end
    end
  end

  describe '#restore!' do
    it 'returns self' do
      instance = test_class.new('ABC')
      expect(instance.restore!).to be(instance)
    end

    it 'calculates and sets the check digit' do
      instance = test_class.new('ABC')
      instance.restore!
      expect(instance.check_digit).to eq(7)
      expect(instance.full_number).to eq('ABC7')
    end

    it 'corrects an incorrect check digit' do
      instance = test_class.new('ABC0')
      instance.restore!
      expect(instance.full_number).to eq('ABC7')
    end

    context 'when format is invalid' do
      it 'raises InvalidFormatError' do
        instance = test_class.new('INVALID')
        expect { instance.restore! }.to raise_error(SecId::InvalidFormatError)
      end
    end
  end

  describe '#calculate_check_digit' do
    it 'calculates the check digit' do
      instance = test_class.new('ABC')
      expect(instance.calculate_check_digit).to eq(7)
    end

    context 'when format is invalid' do
      it 'raises InvalidFormatError' do
        instance = test_class.new('INVALID')
        expect { instance.calculate_check_digit }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when subclass does not implement calculate_check_digit' do
      it 'raises NotImplementedError' do
        instance = CheckableSpecHelper::IncompleteClass.new('ABC')
        expect { instance.calculate_check_digit }.to raise_error(NotImplementedError)
      end
    end
  end

  describe '#to_s' do
    it 'returns identifier with check digit' do
      instance = test_class.new('ABC7')
      expect(instance.to_s).to eq('ABC7')
    end

    it 'returns identifier with nil check digit as empty string' do
      instance = test_class.new('ABC')
      expect(instance.to_s).to eq('ABC')
    end
  end

  describe '.restore' do
    it 'returns the full identifier string with correct check digit' do
      expect(test_class.restore('ABC')).to eq('ABC7')
    end
  end

  describe '.restore!' do
    it 'returns an instance of the class' do
      result = test_class.restore!('ABC')
      expect(result).to be_a(test_class)
      expect(result.to_s).to eq('ABC7')
    end
  end

  describe '.check_digit' do
    it 'creates instance and returns calculated check digit' do
      expect(test_class.check_digit('ABC')).to eq(7)
    end
  end

  describe 'Luhn algorithms' do
    let(:instance) { test_class.new('ABC') }

    describe '#luhn_sum_double_add_double' do
      it 'calculates CUSIP/CEI style sum' do
        # [1, 2, 3, 4] -> even positions (from right): 1, 3; odd: 2, 4
        # (1*2=2, div10mod10=2) + (2, div10mod10=2) + (3*2=6, div10mod10=6) + (4, div10mod10=4) = 14
        digits = [1, 2, 3, 4]
        expect(instance.luhn_sum_double_add_double(digits)).to eq(14)
      end
    end

    describe '#luhn_sum_indexed' do
      it 'calculates FIGI style sum' do
        # [1, 2, 3, 4] -> index 0: 1, index 1: 2*2=4, index 2: 3, index 3: 4*2=8
        # div10mod10: 1 + 4 + 3 + 8 = 16
        digits = [1, 2, 3, 4]
        expect(instance.luhn_sum_indexed(digits)).to eq(16)
      end
    end

    describe '#luhn_sum_standard' do
      it 'calculates ISIN style sum' do
        # [1, 2, 3, 4] -> pairs: (1*2=2, 2), (3*2=6, 4)
        # 2 + 2 + 6 + 4 = 14
        digits = [1, 2, 3, 4]
        expect(instance.luhn_sum_standard(digits)).to eq(14)
      end

      it 'subtracts 9 when doubled value exceeds 9' do
        # [5, 2, 6, 4] -> pairs: (5*2=10-9=1, 2), (6*2=12-9=3, 4)
        # 1 + 2 + 3 + 4 = 10
        digits = [5, 2, 6, 4]
        expect(instance.luhn_sum_standard(digits)).to eq(10)
      end
    end

    describe '#reversed_digits_single' do
      it 'converts identifier to reversed digit array' do
        expect(instance.reversed_digits_single('AB')).to eq([11, 10])
      end
    end

    describe '#reversed_digits_multi' do
      it 'converts identifier to reversed digit array with multi-digit expansion' do
        # A = [1, 0], B = [1, 1], reversed = [1, 1, 0, 1]
        expect(instance.reversed_digits_multi('AB')).to eq([1, 1, 0, 1])
      end
    end
  end
end
