# frozen_string_literal: true

# Shared examples for edge case input handling.
# Tests nil, empty string, and whitespace-only inputs for all identifier types.
RSpec.shared_examples 'handles edge case inputs' do
  let(:identifier_class) { described_class }

  describe 'nil input' do
    let(:instance) { identifier_class.new(nil) }

    it 'returns false for #valid?' do
      expect(instance.valid?).to be(false)
    end

    it 'returns false for #valid_format?' do
      expect(instance.valid_format?).to be(false)
    end

    it 'returns false for .valid?' do
      expect(identifier_class.valid?(nil)).to be(false)
    end

    it 'returns false for .valid_format?' do
      expect(identifier_class.valid_format?(nil)).to be(false)
    end

    context 'when calling restore!/normalize!' do
      # For identifiers with check digits, use restore!
      # For identifiers without check digits (CIK, OCC), use normalize!
      it 'raises InvalidFormatError for instance method' do
        if instance.has_check_digit?
          expect { instance.restore! }.to raise_error(SecId::InvalidFormatError)
        elsif instance.respond_to?(:normalize!)
          expect { instance.normalize! }.to raise_error(SecId::InvalidFormatError)
        end
      end

      it 'raises InvalidFormatError for class method' do
        if identifier_class.new('test').has_check_digit?
          expect { identifier_class.restore!(nil) }.to raise_error(SecId::InvalidFormatError)
        elsif identifier_class.singleton_class.method_defined?(:normalize!)
          expect { identifier_class.normalize!(nil) }.to raise_error(SecId::InvalidFormatError)
        end
      end
    end
  end

  describe 'empty string input' do
    let(:instance) { identifier_class.new('') }

    it 'returns false for #valid?' do
      expect(instance.valid?).to be(false)
    end

    it 'returns false for #valid_format?' do
      expect(instance.valid_format?).to be(false)
    end

    it 'returns false for .valid?' do
      expect(identifier_class.valid?('')).to be(false)
    end

    it 'returns false for .valid_format?' do
      expect(identifier_class.valid_format?('')).to be(false)
    end

    context 'when calling restore!/normalize!' do
      it 'raises InvalidFormatError for instance method' do
        if instance.has_check_digit?
          expect { instance.restore! }.to raise_error(SecId::InvalidFormatError)
        elsif instance.respond_to?(:normalize!)
          expect { instance.normalize! }.to raise_error(SecId::InvalidFormatError)
        end
      end

      it 'raises InvalidFormatError for class method' do
        if identifier_class.new('test').has_check_digit?
          expect { identifier_class.restore!('') }.to raise_error(SecId::InvalidFormatError)
        elsif identifier_class.singleton_class.method_defined?(:normalize!)
          expect { identifier_class.normalize!('') }.to raise_error(SecId::InvalidFormatError)
        end
      end
    end
  end

  describe 'whitespace-only input' do
    let(:instance) { identifier_class.new('   ') }

    it 'returns false for #valid?' do
      expect(instance.valid?).to be(false)
    end

    it 'returns false for #valid_format?' do
      expect(instance.valid_format?).to be(false)
    end

    it 'returns false for .valid?' do
      expect(identifier_class.valid?('   ')).to be(false)
    end

    it 'returns false for .valid_format?' do
      expect(identifier_class.valid_format?('   ')).to be(false)
    end

    context 'when calling restore!/normalize!' do
      it 'raises InvalidFormatError for instance method' do
        if instance.has_check_digit?
          expect { instance.restore! }.to raise_error(SecId::InvalidFormatError)
        elsif instance.respond_to?(:normalize!)
          expect { instance.normalize! }.to raise_error(SecId::InvalidFormatError)
        end
      end

      it 'raises InvalidFormatError for class method' do
        if identifier_class.new('test').has_check_digit?
          expect { identifier_class.restore!('   ') }.to raise_error(SecId::InvalidFormatError)
        elsif identifier_class.singleton_class.method_defined?(:normalize!)
          expect { identifier_class.normalize!('   ') }.to raise_error(SecId::InvalidFormatError)
        end
      end
    end
  end
end
