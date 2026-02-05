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
end
