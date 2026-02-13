# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecId do
  it 'has a version number' do
    expect(SecId::VERSION).not_to be_nil
  end

  describe '.identifiers' do
    it 'returns all 13 identifier classes' do
      expect(described_class.identifiers.size).to eq(13)
    end

    it 'includes all expected classes' do
      expected = [
        SecId::ISIN, SecId::CUSIP, SecId::SEDOL, SecId::FIGI, SecId::LEI,
        SecId::IBAN, SecId::CIK, SecId::OCC, SecId::WKN, SecId::Valoren,
        SecId::CEI, SecId::CFI, SecId::FISN,
      ]
      expect(described_class.identifiers).to match_array(expected)
    end

    it 'returns a copy that does not affect the internal list' do
      list = described_class.identifiers
      list.clear
      expect(described_class.identifiers.size).to eq(13)
    end
  end

  describe '.[]' do
    {
      isin: SecId::ISIN,
      cusip: SecId::CUSIP,
      sedol: SecId::SEDOL,
      figi: SecId::FIGI,
      lei: SecId::LEI,
      iban: SecId::IBAN,
      cik: SecId::CIK,
      occ: SecId::OCC,
      wkn: SecId::WKN,
      valoren: SecId::Valoren,
      cei: SecId::CEI,
      cfi: SecId::CFI,
      fisn: SecId::FISN
    }.each do |key, klass|
      it "looks up #{klass} by :#{key}" do
        expect(described_class[key]).to eq(klass)
      end
    end

    it 'raises ArgumentError for unknown key' do
      expect { described_class[:unknown] }.to raise_error(ArgumentError, /Unknown identifier type/)
    end
  end

  describe '.detect' do
    it 'returns matching type symbols for a valid ISIN' do
      expect(described_class.detect('US5949181045')).to eq([:isin])
    end

    it 'returns multiple matches when types overlap' do
      expect(described_class.detect('514000')).to eq(%i[wkn valoren cik])
    end

    it 'returns empty array for invalid input' do
      expect(described_class.detect('INVALID')).to eq([])
    end

    it 'returns empty array for nil' do
      expect(described_class.detect(nil)).to eq([])
    end
  end

  describe '.valid?' do
    context 'without types' do
      it 'returns true for a valid ISIN' do
        expect(described_class.valid?('US5949181045')).to be true
      end

      it 'returns true for a valid CUSIP' do
        expect(described_class.valid?('594918104')).to be true
      end

      it 'returns false for an invalid identifier' do
        expect(described_class.valid?('INVALID')).to be false
      end

      it 'returns false for nil' do
        expect(described_class.valid?(nil)).to be false
      end

      it 'returns false for empty string' do
        expect(described_class.valid?('')).to be false
      end
    end

    context 'with types' do
      it 'returns true when identifier matches a specified type' do
        expect(described_class.valid?('US5949181045', types: [:isin])).to be true
      end

      it 'returns false when identifier does not match specified type' do
        expect(described_class.valid?('US5949181045', types: [:cusip])).to be false
      end

      it 'returns true when identifier matches one of multiple types' do
        expect(described_class.valid?('594918104', types: %i[cusip sedol])).to be true
      end

      it 'returns false when identifier matches none of the types' do
        expect(described_class.valid?('INVALID', types: %i[isin cusip])).to be false
      end

      it 'raises ArgumentError for unknown type key' do
        expect { described_class.valid?('US5949181045', types: [:unknown]) }
          .to raise_error(ArgumentError, /Unknown identifier type/)
      end
    end
  end
end
