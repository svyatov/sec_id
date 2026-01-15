# frozen_string_literal: true

RSpec.describe SecId::WKN do
  let(:wkn) { described_class.new(wkn_number) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  context 'when WKN is valid' do
    let(:wkn_number) { '514000' }

    it 'parses WKN correctly' do
      expect(wkn.identifier).to eq('514000')
      expect(wkn.check_digit).to be_nil
    end

    it 'returns the full number' do
      expect(wkn.full_number).to eq('514000')
    end

    it 'has no check digit' do
      expect(wkn.has_check_digit?).to be(false)
    end
  end

  context 'when WKN is alphanumeric' do
    let(:wkn_number) { 'CBK100' }

    it 'parses WKN correctly' do
      expect(wkn.identifier).to eq('CBK100')
      expect(wkn.check_digit).to be_nil
    end
  end

  context 'when WKN is lowercase' do
    let(:wkn_number) { 'cbk100' }

    it 'normalizes to uppercase' do
      expect(wkn.identifier).to eq('CBK100')
    end
  end

  describe '.valid?' do
    context 'when WKN is valid' do
      it 'returns true for various valid WKNs' do
        %w[
          514000 CBK100 840400 519000 716460 723610
          A1EWWW BASF11 BAY001 DTR0CK ENAG99 A0D9PT
        ].each do |wkn_number|
          expect(described_class.valid?(wkn_number)).to be(true)
        end
      end
    end

    context 'when WKN is invalid' do
      it 'returns false for wrong length' do
        expect(described_class.valid?('12345')).to be(false)
        expect(described_class.valid?('1234567')).to be(false)
      end

      it 'returns false for forbidden letters I and O' do
        expect(described_class.valid?('ABICD1')).to be(false)
        expect(described_class.valid?('ABOCD1')).to be(false)
      end

      it 'returns false for invalid characters' do
        expect(described_class.valid?('514-00')).to be(false)
        expect(described_class.valid?('51400@')).to be(false)
      end
    end
  end

  describe '.valid_format?' do
    context 'when WKN is valid' do
      it 'returns true for various valid formats' do
        expect(described_class.valid_format?('514000')).to be(true)
        expect(described_class.valid_format?('CBK100')).to be(true)
        expect(described_class.valid_format?('A1EWWW')).to be(true)
      end
    end

    context 'when WKN format is invalid' do
      it 'returns false for invalid formats' do
        expect(described_class.valid_format?('12345')).to be(false)
        expect(described_class.valid_format?('ABCIO1')).to be(false)
      end
    end
  end
end
