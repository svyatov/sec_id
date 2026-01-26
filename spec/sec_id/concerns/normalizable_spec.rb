# frozen_string_literal: true

# Test class for Normalizable concern - defined outside RSpec block to avoid redefinition
module NormalizableSpecHelper
  class TestClass < SecId::Base
    include SecId::Normalizable

    ID_REGEX = /\A(?<padding>0*)(?<identifier>[1-9]\d*)\z/

    def initialize(id) # rubocop:disable Lint/MissingSuper
      parts = parse(id)
      @padding = parts[:padding]
      @identifier = parts[:identifier]
    end

    attr_reader :padding

    def normalize!
      raise SecId::InvalidFormatError, 'Invalid format' unless valid_format?

      @full_number = @identifier.rjust(6, '0')
      @padding = @full_number[0, 6 - @identifier.length]
      @full_number
    end
  end
end

RSpec.describe SecId::Normalizable do
  let(:test_class) { NormalizableSpecHelper::TestClass }

  describe 'when included in a class' do
    it 'adds normalize! class method' do
      expect(test_class).to respond_to(:normalize!)
    end
  end

  describe '#normalize!' do
    context 'when identifier is valid' do
      it 'normalizes to padded format' do
        instance = test_class.new('123')
        expect(instance.normalize!).to eq('000123')
        expect(instance.full_number).to eq('000123')
        expect(instance.padding).to eq('000')
      end

      it 'preserves already normalized identifiers' do
        instance = test_class.new('000123')
        expect(instance.normalize!).to eq('000123')
      end
    end

    context 'when identifier format is invalid' do
      it 'raises InvalidFormatError' do
        instance = test_class.new('invalid')
        expect { instance.normalize! }.to raise_error(SecId::InvalidFormatError)
      end

      it 'raises InvalidFormatError for nil' do
        instance = test_class.new(nil)
        expect { instance.normalize! }.to raise_error(SecId::InvalidFormatError)
      end

      it 'raises InvalidFormatError for empty string' do
        instance = test_class.new('')
        expect { instance.normalize! }.to raise_error(SecId::InvalidFormatError)
      end

      it 'raises InvalidFormatError for whitespace' do
        instance = test_class.new('   ')
        expect { instance.normalize! }.to raise_error(SecId::InvalidFormatError)
      end
    end
  end

  describe '.normalize!' do
    context 'when identifier is valid' do
      it 'creates instance and returns normalized identifier' do
        expect(test_class.normalize!('123')).to eq('000123')
      end
    end

    context 'when identifier format is invalid' do
      it 'raises InvalidFormatError' do
        expect { test_class.normalize!('invalid') }.to raise_error(SecId::InvalidFormatError)
      end

      it 'raises InvalidFormatError for nil' do
        expect { test_class.normalize!(nil) }.to raise_error(SecId::InvalidFormatError)
      end

      it 'raises InvalidFormatError for empty string' do
        expect { test_class.normalize!('') }.to raise_error(SecId::InvalidFormatError)
      end

      it 'raises InvalidFormatError for whitespace' do
        expect { test_class.normalize!('   ') }.to raise_error(SecId::InvalidFormatError)
      end
    end
  end
end
