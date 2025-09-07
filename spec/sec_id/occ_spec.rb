# frozen_string_literal: true

RSpec.describe SecId::OCC do
  let(:occ) { described_class.new(occ_symbol) }

  context 'when OCC symbol is in canonical form' do
    let(:occ_symbol) { 'EQX   260116C00005500' }

    it 'parses OCC symbol correctly' do
      expect(occ.full_symbol).to eq(occ_symbol)
      expect(occ.underlying).to eq('EQX')
      expect(occ.date_str).to eq('260116')
      expect(occ.type).to eq('C')
      expect(occ.instance_variable_get(:@strike_mills)).to eq('00005500')
    end

    describe '#valid?' do
      it 'returns true' do
        expect(occ.valid?).to be(true)
      end
    end

    describe '#normalize!' do
      it 'returns full OCC symbol' do
        expect(occ.normalize!).to eq(occ_symbol)
        expect(occ.full_symbol).to eq(occ_symbol)
      end
    end

    describe '#strike' do
      it 'returns the strike price' do
        expect(occ.strike).to eq(5.5)
      end
    end

    describe '#date' do
      it 'returns the expiry as a date object' do
        expect(occ.date).to eq(Date.new(2026, 1, 16))
      end
    end

    describe '#date_obj' do
      it 'returns the expiry as a date object' do
        expect(occ.date_obj).to eq(Date.new(2026, 1, 16))
      end

      it 'is an alias of #date' do
        expect(occ.method(:date_obj)).to eq(occ.method(:date))
      end
    end

    describe '#to_s' do
      it 'returns the full symbol' do
        expect(occ.to_s).to eq('EQX   260116C00005500')
      end
    end

    describe '#to_str' do
      it 'returns the full symbol' do
        expect(occ.to_str).to eq('EQX   260116C00005500')
      end

      it 'allows implicit string conversion' do
        expect("symbol: #{occ}").to eq('symbol: EQX   260116C00005500')
      end
    end
  end

  context 'when OCC symbol is missing padding' do
    let(:occ_symbol) { 'EQX260116C00005500' }

    it 'parses OCC symbol correctly' do
      expect(occ.underlying).to eq('EQX')
      expect(occ.date_str).to eq('260116')
      expect(occ.type).to eq('C')
      expect(occ.instance_variable_get(:@strike_mills)).to eq('00005500')
    end

    describe '#valid?' do
      it 'returns true' do
        expect(occ.valid?).to be(true)
      end
    end

    describe '#normalize!' do
      it 'normalizes spaces in underlying and returns full OCC symbol in canonical form' do
        expect(occ.normalize!).to eq('EQX   260116C00005500')
        expect(occ.full_symbol).to eq('EQX   260116C00005500')
      end
    end
  end

  describe '.valid?' do
    context 'when OCC symbol strike is zero' do
      it 'returns true' do
        expect(described_class.valid?('CZOO1 240517P00000000')).to be(true)
      end
    end

    context 'when OCC symbol strike is non-zero' do
      it 'returns true' do
        expect(described_class.valid?('CZOO1 240517P00001000')).to be(true)
      end
    end

    context 'when OCC symbol has a bad date' do
      it 'returns false' do
        expect(described_class.valid?('SPX   141199P01950000')).to be(false)
        expect(described_class.valid?('SPX   140022P01950000')).to be(false)
      end
    end

    context 'when OCC symbol is valid' do
      it 'returns true' do
        [
          'TWTR  230120C00040000',
          'X     250620C00050000',
          'CRESY 250919C00010000',
          'AAPL7 140502C00480000',
          'GOLG1 140920P00800000',
          '1GOOGL251219P00131000',
          '4XSP  241115C00009300',
          'VIX   130213C00010000',
        ].each { |occ_symbol| expect(described_class.valid?(occ_symbol)).to be(true) }
      end
    end
  end

  describe '.normalize!' do
    context 'when OCC symbol is invalid' do
      it 'raises an error' do
        expect { described_class.normalize!('KGC US 07/17/10 C13') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.normalize!('X     25 620c00050000') }.to raise_error(SecId::InvalidFormatError)
        expect { described_class.normalize!('ZVZZT') }.to raise_error(SecId::InvalidFormatError)
      end
    end

    context 'when OCC symbol is valid' do
      it 'normalizes padding and returns full OCC symbol in canonical form' do
        expect(described_class.normalize!('PAAS1250919C00022500')).to eq('PAAS1 250919C00022500')
        expect(described_class.normalize!('X 250620C00050000')).to eq('X     250620C00050000')
        expect(described_class.normalize!('X250620C00050000')).to eq('X     250620C00050000')
        expect(described_class.normalize!('1AMD 250919P00085010')).to eq('1AMD  250919P00085010')
        expect(described_class.normalize!('1AMD250919P00085010')).to eq('1AMD  250919P00085010')
      end
    end
  end

  describe '.valid_format?' do
    context 'when OCC symbol has an unsupported underlying symbol' do
      it 'returns false' do
        expect(described_class.valid_format?('GOOGLE251219P00131000')).to be(false)
        expect(described_class.valid_format?('OAKpA 240517C00001000')).to be(false)
        expect(described_class.valid_format?('BRK.B 240517C00001000')).to be(false)
        expect(described_class.valid_format?('BRK B 240517C00001000')).to be(false)
      end
    end

    context 'when OCC symbol has an invalid type' do
      it 'returns false' do
        expect(described_class.valid_format?('CZOO1 240517c00001000')).to be(false)
        expect(described_class.valid_format?('CZOO1 240517p00001000')).to be(false)
        expect(described_class.valid_format?('CZOO1 240517o00001000')).to be(false)
        expect(described_class.valid_format?('CZOO1 240517x00001000')).to be(false)
        expect(described_class.valid_format?('CZOO1 240517X00001000')).to be(false)
      end
    end

    context 'when OCC symbol has four-digit year' do
      it 'returns false' do
        expect(described_class.valid_format?('PAAS1 20250919C00022500')).to be(false)
        expect(described_class.valid_format?('X     20250620C00050000')).to be(false)
      end
    end

    context 'when OCC symbol has extra leading zeros in whole part of strike' do
      it 'returns false' do
        expect(described_class.valid_format?('PAAS1 250919C000000022500')).to be(false)
        expect(described_class.valid_format?('X     250620C000000050000')).to be(false)
      end
    end

    context 'when OCC symbol is valid or has normalizable attributes' do
      it 'returns true' do
        expect(described_class.valid_format?('X250620C00050000')).to be(true)
        expect(described_class.valid_format?('X 250620C00050000')).to be(true)
        expect(described_class.valid_format?('X  250620C00050000')).to be(true)
        expect(described_class.valid_format?('X   250620C00050000')).to be(true)
      end
    end
  end

  describe '.build' do
    context 'with component strings in canonical form' do
      it 'composes OCC symbol' do
        components = { underlying: "X\s\s\s\s\s", date: '250620', type: 'C', strike: '00050000' }
        full_symbol = components.values.join
        occ = described_class.build(**components)
        expect(occ.full_symbol).to eq(full_symbol)
      end
    end

    context 'with objects' do
      it 'composes OCC symbol' do
        components = { underlying: 'X', date: Date.new(2025, 6, 20), type: :C, strike: 50 }
        occ = described_class.build(**components)
        expect(occ.full_symbol).to eq("X\s\s\s\s\s250620C00050000")
      end
    end

    context 'with valid inputs' do
      it 'composes OCC symbol with padded underlying' do
        occ = described_class.build(underlying: 'X', date: '250620', type: 'C', strike: 50)
        expect(occ.underlying).to eq('X')
        expect(occ.full_symbol).to eq('X     250620C00050000')
      end

      it 'composes OCC symbol when date is a Date object' do
        date = Date.new(2026, 1, 16)
        occ = described_class.build(underlying: 'EQX', date: date, type: 'C', strike: 5.5)
        expect(occ.underlying).to eq('EQX')
        expect(occ.date_str).to eq('260116')
        expect(occ.type).to eq('C')
        expect(occ.strike).to eq(5.5)
        expect(occ.full_symbol).to eq('EQX   260116C00005500')
      end

      it 'composes OCC symbol when date is a string' do
        occ = described_class.build(underlying: 'AAPL', date: '250919', type: 'P', strike: 150)
        expect(occ.underlying).to eq('AAPL')
        expect(occ.date_str).to eq('250919')
        expect(occ.type).to eq('P')
        expect(occ.strike).to eq(150.0)
        expect(occ.full_symbol).to eq('AAPL  250919P00150000')
      end

      it 'composes OCC symbol when date is an arbitrary parseable string' do
        ["Jan 16 '26", '16JAN26'].each do |date|
          occ = described_class.build(underlying: 'AAPL', date: date, type: 'P', strike: 150)
          expect(occ.date_str).to eq('260116')
        end
      end

      it 'composes OCC symbol with decimal strike prices' do
        occ = described_class.build(underlying: '2DJX', date: '250321', type: 'C', strike: 415.3)
        expect(occ.strike).to eq(415.3)
        expect(occ.full_symbol).to eq('2DJX  250321C00415300')
      end

      it 'composes OCC symbol with rational strike prices' do
        occ = described_class.build(underlying: 'EQX', date: '260116', type: 'C', strike: Rational(11, 2))
        expect(occ.strike).to eq(5.5)
        expect(occ.full_symbol).to eq('EQX   260116C00005500')
      end
    end

    context 'with invalid inputs' do
      it 'raises error when missing keywords' do
        components = { underlying: 'AAPL', date: '250919', type: 'C' }
        expect { described_class.build(**components) }.to raise_error(ArgumentError, 'missing keyword: :strike')
      end

      it 'raises error when date is invalid' do
        components = { underlying: 'AAPL', date: '0', type: 'C', strike: 240 }
        %w[01/16/2026 0 2030-00-99].each do |date|
          components[:date] = date
          expect { described_class.build(**components) }.to raise_error(Date::Error, 'invalid date')
        end
      end

      it 'raises error when strike is not numeric' do
        components = { underlying: 'AAPL', date: '250919', type: 'C', strike: '240' }
        expect { described_class.build(**components) }
          .to raise_error(ArgumentError, 'Strike must be numeric or an 8-char string!')
      end
    end

    context 'with large strike' do
      it 'processes the value accurately' do
        strike = 98_765.321
        occ = described_class.build(underlying: 'X', date: '250620', type: 'C', strike: strike)
        expect(occ.strike).to eq(strike)
      end
    end
  end
end
