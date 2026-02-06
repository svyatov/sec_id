# frozen_string_literal: true

RSpec.describe SecId::FISN do
  let(:fisn) { described_class.new(fisn_code) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Financial Instrument Short Name',
                  id_length: 3..35,
                  has_check_digit: false,
                  has_normalization: false

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'APPLE INC/SH',
                  invalid_length_id: 'AB',
                  invalid_chars_id: 'APPLE-INC/SH!'

  describe 'valid FISN parsing' do
    context 'when FISN is simple (APPLE INC/SH)' do
      let(:fisn_code) { 'APPLE INC/SH' }

      it 'parses identifier correctly' do
        expect(fisn.identifier).to eq('APPLE INC/SH')
      end

      it 'parses issuer and description' do
        expect(fisn.issuer).to eq('APPLE INC')
        expect(fisn.description).to eq('SH')
      end
    end

    context 'when FISN has numeric characters' do
      let(:fisn_code) { 'COMPANY 123/BOND 2025' }

      it 'parses identifier correctly' do
        expect(fisn.identifier).to eq('COMPANY 123/BOND 2025')
      end

      it 'parses issuer and description' do
        expect(fisn.issuer).to eq('COMPANY 123')
        expect(fisn.description).to eq('BOND 2025')
      end
    end

    context 'when FISN is lowercase' do
      let(:fisn_code) { 'apple inc/sh' }

      it 'normalizes to uppercase' do
        expect(fisn.identifier).to eq('APPLE INC/SH')
        expect(fisn.issuer).to eq('APPLE INC')
        expect(fisn.description).to eq('SH')
      end
    end

    context 'when FISN has mixed case' do
      let(:fisn_code) { 'Apple Inc/Shares' }

      it 'normalizes to uppercase' do
        expect(fisn.identifier).to eq('APPLE INC/SHARES')
        expect(fisn.issuer).to eq('APPLE INC')
        expect(fisn.description).to eq('SHARES')
      end
    end

    context 'when FISN has minimum lengths (A/B)' do
      let(:fisn_code) { 'A/B' }

      it 'parses correctly' do
        expect(fisn.identifier).to eq('A/B')
        expect(fisn.issuer).to eq('A')
        expect(fisn.description).to eq('B')
      end

      it 'is valid' do
        expect(fisn.valid?).to be(true)
        expect(fisn.valid_format?).to be(true)
      end
    end

    context 'when FISN has maximum lengths' do
      # 15 char issuer + 1 slash + 19 char description = 35 chars
      let(:fisn_code) { 'ISSUER NAME 123/DESCRIPTION 1234567' }

      it 'parses correctly' do
        expect(fisn.issuer).to eq('ISSUER NAME 123')
        expect(fisn.issuer.length).to eq(15)
        expect(fisn.description).to eq('DESCRIPTION 1234567')
        expect(fisn.description.length).to eq(19)
      end
    end

    context 'when issuer is exactly 14 chars (just under max)' do
      let(:fisn_code) { 'ABCDEFGHIJKLMN/SH' }

      it 'parses correctly and is valid' do
        expect(fisn.issuer).to eq('ABCDEFGHIJKLMN')
        expect(fisn.issuer.length).to eq(14)
        expect(fisn.valid?).to be(true)
      end
    end

    context 'when description is exactly 18 chars (just under max)' do
      let(:fisn_code) { 'A/ABCDEFGHIJKLMNOPQR' }

      it 'parses correctly and is valid' do
        expect(fisn.description).to eq('ABCDEFGHIJKLMNOPQR')
        expect(fisn.description.length).to eq(18)
        expect(fisn.valid?).to be(true)
      end
    end

    context 'when issuer is pure numeric' do
      let(:fisn_code) { '123456/BOND' }

      it 'parses correctly and is valid' do
        expect(fisn.issuer).to eq('123456')
        expect(fisn.description).to eq('BOND')
        expect(fisn.valid?).to be(true)
      end
    end

    context 'when description is pure numeric' do
      let(:fisn_code) { 'APPLE/123456' }

      it 'parses correctly and is valid' do
        expect(fisn.issuer).to eq('APPLE')
        expect(fisn.description).to eq('123456')
        expect(fisn.valid?).to be(true)
      end
    end

    context 'when FISN is all-numeric' do
      let(:fisn_code) { '123/456' }

      it 'parses correctly and is valid' do
        expect(fisn.issuer).to eq('123')
        expect(fisn.description).to eq('456')
        expect(fisn.valid?).to be(true)
      end
    end

    context 'when FISN has multiple consecutive spaces' do
      let(:fisn_code) { 'APPLE  INC/SH' }

      it 'parses correctly preserving spaces' do
        expect(fisn.issuer).to eq('APPLE  INC')
        expect(fisn.description).to eq('SH')
        expect(fisn.valid?).to be(true)
      end
    end
  end

  describe '.valid?' do
    context 'when FISN is valid' do
      it 'returns true for various valid FISN codes' do
        [
          'APPLE/SH',
          'A/B',
          'MICROSOFT/COMMON',
          'COMPANY 123/BOND',
          'ABC DEF/XYZ 123',
        ].each do |code|
          expect(described_class.valid?(code.gsub('\\', ''))).to be(true), "Expected #{code} to be valid"
        end
      end

      it 'returns true for max issuer length (15 chars)' do
        expect(described_class.valid?('ABCDEFGHIJKLMNO/SH')).to be(true)
      end

      it 'returns true for max description length (19 chars)' do
        expect(described_class.valid?('A/ABCDEFGHIJKLMNOPQRS')).to be(true)
      end

      it 'returns true for max total length (35 chars)' do
        # 15 char issuer + 1 slash + 19 char description = 35 chars
        expect(described_class.valid?('ABCDEFGHIJKLMNO/ABCDEFGHIJKLMNOPQRS')).to be(true)
      end
    end

    context 'when FISN is invalid' do
      it 'returns false for missing slash' do
        expect(described_class.valid?('APPLE INC SH')).to be(false)
      end

      it 'returns false for empty issuer' do
        expect(described_class.valid?('/SH')).to be(false)
      end

      it 'returns false for empty description' do
        expect(described_class.valid?('APPLE/')).to be(false)
      end

      it 'returns false for issuer too long (>15 chars)' do
        expect(described_class.valid?('ABCDEFGHIJKLMNOP/SH')).to be(false)
      end

      it 'returns false for issuer exactly 16 chars (just over max)' do
        expect(described_class.valid?('ABCDEFGHIJKLMNOP/X')).to be(false)
      end

      it 'returns false for description too long (>19 chars)' do
        expect(described_class.valid?('A/ABCDEFGHIJKLMNOPQRST')).to be(false)
      end

      it 'returns false for description exactly 20 chars (just over max)' do
        expect(described_class.valid?('A/ABCDEFGHIJKLMNOPQRS1')).to be(false)
      end

      it 'returns false for invalid characters' do
        expect(described_class.valid?('APPLE-INC/SH')).to be(false)
        expect(described_class.valid?('APPLE_INC/SH')).to be(false)
        expect(described_class.valid?('APPLE.INC/SH')).to be(false)
        expect(described_class.valid?('APPLE!/SH')).to be(false)
      end

      it 'returns false for multiple slashes' do
        expect(described_class.valid?('APPLE/INC/SH')).to be(false)
      end

      it 'allows leading space in issuer (space is valid character)' do
        expect(described_class.valid?(' APPLE/SH')).to be(true)
      end

      it 'allows trailing space in issuer' do
        expect(described_class.valid?('APPLE /SH')).to be(true)
      end

      it 'allows leading space in description (space is valid character)' do
        expect(described_class.valid?('APPLE/ SH')).to be(true)
      end

      it 'allows trailing space in description' do
        expect(described_class.valid?('APPLE/SH ')).to be(true)
      end
    end
  end

  describe '.valid_format?' do
    context 'when format is valid' do
      it 'returns true for valid formats' do
        expect(described_class.valid_format?('APPLE INC/SH')).to be(true)
        expect(described_class.valid_format?('A/B')).to be(true)
      end
    end

    context 'when format is invalid' do
      it 'returns false for missing slash' do
        expect(described_class.valid_format?('APPLE INC SH')).to be(false)
      end

      it 'returns false for invalid characters' do
        expect(described_class.valid_format?('APPLE-INC/SH')).to be(false)
      end
    end
  end

  describe '#to_s' do
    let(:fisn_code) { 'APPLE INC/SH' }

    it 'returns the identifier' do
      expect(fisn.to_s).to eq('APPLE INC/SH')
    end
  end

  describe '#full_number' do
    let(:fisn_code) { 'apple inc/sh' }

    it 'returns the normalized (uppercased) full number' do
      expect(fisn.full_number).to eq('APPLE INC/SH')
    end
  end
end
