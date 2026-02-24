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

    context 'with on_ambiguous: :first (default)' do
      it 'returns the most specific match' do
        expect(described_class.parse('514000', on_ambiguous: :first)).to be_a(SecID::WKN)
      end
    end

    context 'with on_ambiguous: :raise' do
      it 'returns instance for unambiguous input' do
        result = described_class.parse('US5949181045', on_ambiguous: :raise)
        expect(result).to be_a(SecID::ISIN)
      end

      it 'raises AmbiguousMatchError for ambiguous input' do
        expect { described_class.parse('514000', on_ambiguous: :raise) }
          .to raise_error(SecID::AmbiguousMatchError, /matches/)
      end

      it 'includes candidates in error message' do
        expect { described_class.parse('514000', on_ambiguous: :raise) }
          .to raise_error(SecID::AmbiguousMatchError, /wkn.*valoren.*cik/i)
      end

      it 'returns nil for no match' do
        expect(described_class.parse('INVALID', on_ambiguous: :raise)).to be_nil
      end
    end

    context 'with on_ambiguous: :all' do
      it 'returns array of all matching instances for ambiguous input' do
        results = described_class.parse('514000', on_ambiguous: :all)
        expect(results).to be_an(Array)
        expect(results.size).to eq(3)
        expect(results.map(&:class)).to eq([SecID::WKN, SecID::Valoren, SecID::CIK])
      end

      it 'returns single-element array for unambiguous input' do
        results = described_class.parse('US5949181045', on_ambiguous: :all)
        expect(results.size).to eq(1)
        expect(results.first).to be_a(SecID::ISIN)
      end

      it 'returns empty array for no match' do
        expect(described_class.parse('INVALID', on_ambiguous: :all)).to eq([])
      end

      it 'respects types: filter' do
        results = described_class.parse('514000', types: [:valoren], on_ambiguous: :all)
        expect(results.size).to eq(1)
        expect(results.first).to be_a(SecID::Valoren)
      end
    end

    context 'with invalid on_ambiguous value' do
      it 'raises ArgumentError' do
        expect { described_class.parse('x', on_ambiguous: :bogus) }
          .to raise_error(ArgumentError, /Unknown on_ambiguous mode/)
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

    context 'with on_ambiguous: :all' do
      it 'raises InvalidFormatError for no match' do
        expect { described_class.parse!('INVALID', on_ambiguous: :all) }
          .to raise_error(SecID::InvalidFormatError)
      end

      it 'returns array of matches' do
        result = described_class.parse!('514000', on_ambiguous: :all)
        expect(result.size).to eq(3)
      end
    end

    context 'with on_ambiguous: :raise' do
      it 'raises AmbiguousMatchError for ambiguous input' do
        expect { described_class.parse!('514000', on_ambiguous: :raise) }
          .to raise_error(SecID::AmbiguousMatchError)
      end

      it 'raises InvalidFormatError for no match' do
        expect { described_class.parse!('INVALID', on_ambiguous: :raise) }
          .to raise_error(SecID::InvalidFormatError)
      end
    end
  end

  describe '.extract' do
    it 'finds identifiers in freeform text' do
      matches = described_class.extract('Buy US5949181045 now')
      expect(matches.size).to eq(1)
      expect(matches.first.type).to eq(:isin)
    end

    it 'returns empty array for no matches' do
      expect(described_class.extract('hello world')).to eq([])
    end

    it 'supports types: filtering' do
      matches = described_class.extract('514000', types: [:valoren])
      expect(matches.first.type).to eq(:valoren)
    end
  end

  describe '.scan' do
    it 'returns Enumerator' do
      expect(described_class.scan('text')).to be_an(Enumerator)
    end
  end

  describe '.explain' do
    it 'shows valid candidate for a valid ISIN' do
      result = described_class.explain('US5949181045')
      isin_candidate = result[:candidates].find { |c| c[:type] == :isin }
      expect(isin_candidate[:valid]).to be(true)
      expect(isin_candidate[:errors]).to eq([])
    end

    it 'shows invalid_check_digit for wrong check digit' do
      result = described_class.explain('US5949181040')
      isin_candidate = result[:candidates].find { |c| c[:type] == :isin }
      expect(isin_candidate[:valid]).to be(false)
      expect(isin_candidate[:errors].first[:error]).to eq(:invalid_check_digit)
    end

    it 'shows invalid_length for wrong length' do
      result = described_class.explain('US594918')
      isin_candidate = result[:candidates].find { |c| c[:type] == :isin }
      expect(isin_candidate[:valid]).to be(false)
      error_codes = isin_candidate[:errors].map { |e| e[:error] }
      expect(error_codes).to include(:invalid_length)
    end

    it 'filters with types:' do
      result = described_class.explain('US5949181045', types: %i[isin cusip])
      expect(result[:candidates].size).to eq(2)
      expect(result[:candidates].map { |c| c[:type] }).to eq(%i[isin cusip])
    end

    it 'returns input key' do
      result = described_class.explain('  US5949181045  ')
      expect(result[:input]).to eq('US5949181045')
    end

    it 'handles nil input' do
      result = described_class.explain(nil)
      expect(result[:input]).to eq('')
      expect(result[:candidates]).to all(include(valid: false))
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
