# frozen_string_literal: true

RSpec.describe SecID::Scanner do
  describe 'SecID.extract' do
    describe 'single-type extraction' do
      it 'finds ISIN in text' do
        matches = SecID.extract('Buy US5949181045 now')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:isin)
        expect(matches.first.range).to eq(4...16)
      end

      it 'finds CUSIP in text' do
        matches = SecID.extract('CUSIP: 594918104')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:cusip)
      end

      it 'finds SEDOL in text' do
        matches = SecID.extract('SEDOL B0YBKJ7 listed')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:sedol)
      end

      it 'finds FIGI in text' do
        matches = SecID.extract('FIGI BBG000BLNNH6')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:figi)
      end

      it 'finds LEI in text' do
        matches = SecID.extract('LEI 7LTWFZYICNSX8D621K86')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:lei)
      end

      it 'finds IBAN in text' do
        matches = SecID.extract('IBAN: DE89370400440532013000')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:iban)
      end

      it 'finds CIK in text' do
        matches = SecID.extract('CIK 0000320193')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:cik)
      end

      it 'finds CEI in text' do
        matches = SecID.extract('CEI A0BCDEFGH1')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:cei)
      end

      it 'finds WKN in text' do
        matches = SecID.extract('WKN 514000')
        types = matches.map(&:type)
        expect(types).to include(:wkn)
      end
    end

    describe 'compound patterns' do
      it 'finds OCC with structural spaces' do
        matches = SecID.extract('Buy AAPL  210917C00150000 expires')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:occ)
      end

      it 'finds FISN with slash' do
        matches = SecID.extract('APPLE INC/SH END')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:fisn)
      end
    end

    describe 'hyphenated identifiers' do
      it 'extracts ISIN with hyphens' do
        matches = SecID.extract('ID: US-5949-1810-45')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:isin)
        expect(matches.first.raw).to eq('US-5949-1810-45')
        expect(matches.first.identifier.normalized).to eq('US5949181045')
      end

      it 'extracts IBAN with hyphens' do
        matches = SecID.extract('IBAN: DE89-3704-0044-0532-0130-00')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:iban)
      end
    end

    describe 'multiple identifiers' do
      it 'finds multiple identifiers left-to-right' do
        matches = SecID.extract('Portfolio: US5949181045, 594918104, B0YBKJ7')
        expect(matches.size).to eq(3)
        expect(matches.map(&:type)).to eq(%i[isin cusip sedol])
      end

      it 'finds ISIN and CUSIP in text' do
        matches = SecID.extract('ISIN US0378331005 CUSIP 037833100')
        expect(matches.size).to eq(2)
        expect(matches.map(&:type)).to eq(%i[isin cusip])
      end
    end

    describe 'types: filtering' do
      it 'restricts to specified types' do
        matches = SecID.extract('US5949181045 594918104', types: [:isin])
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:isin)
      end

      it 'forces ambiguous input to specific type' do
        matches = SecID.extract('514000', types: [:valoren])
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:valoren)
      end

      it 'returns empty when no types match' do
        expect(SecID.extract('hello world', types: [:isin])).to eq([])
      end
    end

    describe 'edge cases' do
      it 'returns empty array for nil' do
        expect(SecID.extract(nil)).to eq([])
      end

      it 'returns empty array for empty string' do
        expect(SecID.extract('')).to eq([])
      end

      it 'returns no matches for normal prose' do
        expect(SecID.extract('hello world')).to eq([])
      end

      it 'detects lowercase input' do
        matches = SecID.extract('isin: us5949181045')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:isin)
      end

      it 'skips invalid check digit' do
        expect(SecID.extract('US5949181040 is wrong')).to eq([])
      end
    end

    describe 'false-positive rejection' do
      it 'does not match currency amounts' do
        expect(SecID.extract('Revenue was $150,000 in Q3')).to eq([])
      end

      it 'does not match URLs' do
        expect(SecID.extract('Visit https://example.com/path')).to eq([])
      end

      it 'does not match email addresses' do
        expect(SecID.extract('Email user@host.com')).to eq([])
      end

      it 'does not match PROFIT (invalid CFI category P)' do
        # P is not a valid CFI category code
        expect(SecID.extract('PROFIT doubled')).to eq([])
      end

      it 'does not match identifiers embedded in words' do
        expect(SecID.extract('xUS5949181045y')).to eq([])
      end

      it 'does not match phone numbers as SEDOL' do
        matches = SecID.extract('Call 555-1234 today')
        types = matches.map(&:type)
        expect(types).not_to include(:sedol)
      end

      it 'extracts token at underscore boundaries' do
        matches = SecID.extract('prefix_US5949181045_suffix')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:isin)
      end

      it 'matches RANDOM as CFI (valid category R, valid group A)' do
        matches = SecID.extract('The word RANDOM here')
        expect(matches.size).to eq(1)
        expect(matches.first.type).to eq(:cfi)
      end
    end

    describe 'match structure' do
      subject(:match) { SecID.extract('Buy US5949181045 now').first }

      it 'has type as Symbol' do
        expect(match.type).to be_a(Symbol)
      end

      it 'has raw as String' do
        expect(match.raw).to be_a(String)
        expect(match.raw).to eq('US5949181045')
      end

      it 'has range as Range' do
        expect(match.range).to be_a(Range)
        expect(match.range).to eq(4...16)
      end

      it 'has identifier as SecID::Base subclass' do
        expect(match.identifier).to be_a(SecID::Base)
        expect(match.identifier).to be_valid
      end

      it 'provides access to identifier attributes' do
        expect(match.identifier.country_code).to eq('US')
      end

      it 'is immutable (Data.define)' do
        expect(match).to be_a(Data)
      end
    end
  end

  describe 'SecID.scan' do
    it 'returns Enumerator when no block given' do
      result = SecID.scan('Buy US5949181045 now')
      expect(result).to be_an(Enumerator)
    end

    it 'yields matches when block given' do
      matches = []
      SecID.scan('Buy US5949181045 now') { |m| matches << m }
      expect(matches.size).to eq(1)
      expect(matches.first.type).to eq(:isin)
    end

    it 'supports enumerator chaining' do
      types = SecID.scan('US5949181045 594918104').map(&:type)
      expect(types).to eq(%i[isin cusip])
    end
  end

  describe 'performance' do
    it 'scans 1000-word text with identifiers in reasonable time' do
      words = Array.new(990) { ('a'..'z').to_a.sample(5).join }
      identifiers = %w[US5949181045 594918104 B0YBKJ7 BBG000BLNNH6 7LTWFZYICNSX8D621K86
                       DE89370400440532013000 0000320193 514000 A0BCDEFGH1 ESVUFR]
      10.times { |i| words.insert(i * 100, identifiers[i]) }
      text = words.join(' ')

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      matches = SecID.extract(text)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

      expect(matches.size).to be >= 10
      expect(elapsed).to be < 1.0
    end
  end
end
