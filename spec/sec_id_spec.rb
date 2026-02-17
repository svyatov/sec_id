# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecID do
  it 'has a version number' do
    expect(SecID::VERSION).not_to be_nil
  end

  describe '.identifiers' do
    it 'returns all 13 identifier classes' do
      expect(described_class.identifiers.size).to eq(13)
    end

    it 'includes all expected classes' do
      expected = [
        SecID::ISIN, SecID::CUSIP, SecID::SEDOL, SecID::FIGI, SecID::LEI,
        SecID::IBAN, SecID::CIK, SecID::OCC, SecID::WKN, SecID::Valoren,
        SecID::CEI, SecID::CFI, SecID::FISN,
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
      isin: SecID::ISIN,
      cusip: SecID::CUSIP,
      sedol: SecID::SEDOL,
      figi: SecID::FIGI,
      lei: SecID::LEI,
      iban: SecID::IBAN,
      cik: SecID::CIK,
      occ: SecID::OCC,
      wkn: SecID::WKN,
      valoren: SecID::Valoren,
      cei: SecID::CEI,
      cfi: SecID::CFI,
      fisn: SecID::FISN
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

  describe '.parse' do
    context 'without types' do
      it 'returns an ISIN instance for a valid ISIN' do
        result = described_class.parse('US5949181045')
        expect(result).to be_a(SecID::ISIN)
        expect(result).to be_valid
      end

      it 'returns a CUSIP instance for a valid CUSIP' do
        result = described_class.parse('594918104')
        expect(result).to be_a(SecID::CUSIP)
        expect(result).to be_valid
      end

      it 'returns the most specific match for ambiguous input' do
        expect(described_class.parse('514000')).to be_a(SecID::WKN)
      end

      it 'returns nil for an invalid string' do
        expect(described_class.parse('INVALID')).to be_nil
      end

      it 'returns nil for nil' do
        expect(described_class.parse(nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(described_class.parse('')).to be_nil
      end

      it 'returns nil for whitespace-only string' do
        expect(described_class.parse('   ')).to be_nil
      end
    end

    context 'with types' do
      it 'returns a matching instance for a single type' do
        result = described_class.parse('594918104', types: [:cusip])
        expect(result).to be_a(SecID::CUSIP)
        expect(result).to be_valid
      end

      it 'returns the first matching instance among multiple types' do
        result = described_class.parse('594918104', types: %i[cusip sedol])
        expect(result).to be_a(SecID::CUSIP)
      end

      it 'returns nil when identifier does not match specified type' do
        expect(described_class.parse('594918104', types: [:sedol])).to be_nil
      end

      it 'raises ArgumentError for unknown type key' do
        expect { described_class.parse('594918104', types: [:unknown]) }
          .to raise_error(ArgumentError, /Unknown identifier type/)
      end

      it 'returns nil for empty types array' do
        expect(described_class.parse('US5949181045', types: [])).to be_nil
      end
    end
  end

  describe '.parse!' do
    it 'returns an ISIN instance for a valid ISIN' do
      result = described_class.parse!('US5949181045')
      expect(result).to be_a(SecID::ISIN)
      expect(result).to be_valid
    end

    it 'raises InvalidFormatError for an invalid string' do
      expect { described_class.parse!('INVALID') }.to raise_error(SecID::InvalidFormatError)
    end

    it 'raises InvalidFormatError for nil' do
      expect { described_class.parse!(nil) }.to raise_error(SecID::InvalidFormatError)
    end

    it 'raises InvalidFormatError for empty string' do
      expect { described_class.parse!('') }.to raise_error(SecID::InvalidFormatError)
    end

    it 'raises InvalidFormatError for whitespace-only string' do
      expect { described_class.parse!('   ') }.to raise_error(SecID::InvalidFormatError)
    end

    it 'includes the input string in the error message' do
      expect { described_class.parse!('INVALID') }
        .to raise_error(SecID::InvalidFormatError, /"INVALID"/)
    end

    it 'includes types in the error message when specified' do
      expect { described_class.parse!('INVALID', types: [:cusip]) }
        .to raise_error(SecID::InvalidFormatError, /\[:cusip\]/)
    end

    context 'with types' do
      it 'returns a matching instance' do
        result = described_class.parse!('594918104', types: [:cusip])
        expect(result).to be_a(SecID::CUSIP)
      end

      it 'raises InvalidFormatError when no type matches' do
        expect { described_class.parse!('594918104', types: [:sedol]) }
          .to raise_error(SecID::InvalidFormatError)
      end
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
