# frozen_string_literal: true

# Shared examples for edge case input handling.
# Tests nil, empty string, and whitespace-only inputs for all identifier types.
# Only tests basic validation (valid?, valid_format?).
# Edge cases for restore!/normalize! are covered in their respective shared examples.
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
  end
end
