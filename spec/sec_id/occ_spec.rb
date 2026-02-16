# frozen_string_literal: true

RSpec.describe SecId::OCC do
  let(:occ) { described_class.new(occ_symbol) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'OCC Option Symbol',
                  id_length: (16..21),
                  has_check_digit: false

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'AAPL  210917C00150000',
                  invalid_length_id: 'AAPL',
                  invalid_chars_id: 'AAPL!!210917C00150000'

  it_behaves_like 'a validate! identifier',
                  valid_id: 'AAPL  210917C00150000',
                  invalid_length_id: 'AAPL',
                  invalid_chars_id: 'AAPL!!210917C00150000'

  # Normalization
  it_behaves_like 'a normalizable identifier',
                  valid_id: 'EQX   260116C00005500',
                  canonical_id: 'EQX   260116C00005500',
                  dirty_id: 'eqx   260116c00005500',
                  invalid_id: 'ZVZZT'

  context 'when OCC symbol is in canonical form' do
    let(:occ_symbol) { 'EQX   260116C00005500' }

    it 'parses OCC symbol correctly' do
      expect(occ.full_id).to eq(occ_symbol)
      expect(occ.underlying).to eq('EQX')
      expect(occ.date_str).to eq('260116')
      expect(occ.type).to eq('C')
      expect(occ.instance_variable_get(:@strike_mills)).to eq('00005500')
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
  end

  describe '#errors' do
    context 'when date is unparseable' do
      it 'returns :invalid_date error' do
        result = described_class.new('SPX   141199P01950000').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_date])
        expect(result.details.first[:message]).to match(/cannot be parsed/)
      end
    end

    context 'when date month is invalid' do
      it 'returns :invalid_date error' do
        result = described_class.new('SPX   140022P01950000').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_date])
      end
    end

    context 'when date day is impossible (Feb 30)' do
      it 'returns :invalid_date error' do
        result = described_class.new('AAPL  210230C00150000').errors
        expect(result.valid?).to be(false)
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_date])
      end
    end
  end

  describe '#date' do
    context 'when date is unparseable' do
      let(:occ_symbol) { 'AAPL  210230C00150000' }

      it 'returns nil' do
        expect(occ.date).to be_nil
      end

      it 'memoizes the nil result' do
        occ.date
        occ.date
        expect(occ.date).to be_nil
      end
    end
  end

  describe '#validate!' do
    context 'when date is unparseable' do
      it 'raises InvalidStructureError' do
        expect { described_class.new('SPX   141199P01950000').validate! }
          .to raise_error(SecId::InvalidStructureError, /cannot be parsed/)
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

  describe '.normalize' do
    context 'when OCC symbol is valid' do
      it 'normalizes padding for various OCC symbols' do
        expect(described_class.normalize('PAAS1250919C00022500')).to eq('PAAS1 250919C00022500')
        expect(described_class.normalize('X 250620C00050000')).to eq('X     250620C00050000')
        expect(described_class.normalize('X250620C00050000')).to eq('X     250620C00050000')
        expect(described_class.normalize('1AMD 250919P00085010')).to eq('1AMD  250919P00085010')
        expect(described_class.normalize('1AMD250919P00085010')).to eq('1AMD  250919P00085010')
      end
    end
  end

  describe '.compose_symbol' do
    it 'pads underlying to 6 characters' do
      result = described_class.compose_symbol('X', '250620', 'C', '00050000')
      expect(result).to eq('X     250620C00050000')
    end

    it 'does not pad 6-character underlying' do
      result = described_class.compose_symbol('1GOOGL', '251219', 'P', '00131000')
      expect(result).to eq('1GOOGL251219P00131000')
    end

    it 'formats strike to 8 digits' do
      result = described_class.compose_symbol('AAPL', '250919', 'C', 150_000)
      expect(result).to eq('AAPL  250919C00150000')
    end
  end

  describe '.build' do
    context 'with 1-character underlying' do
      it 'pads to 6 characters' do
        occ = described_class.build(underlying: 'X', date: '250620', type: 'C', strike: 50)
        expect(occ.full_id).to eq('X     250620C00050000')
        expect(occ.underlying).to eq('X')
      end
    end

    context 'with 6-character underlying' do
      it 'uses full width without extra padding' do
        occ = described_class.build(underlying: '1GOOGL', date: '251219', type: 'P', strike: 131)
        expect(occ.full_id).to eq('1GOOGL251219P00131000')
        expect(occ.underlying).to eq('1GOOGL')
      end
    end

    context 'with high precision decimal strike' do
      it 'truncates to mills (thousandths)' do
        occ = described_class.build(underlying: 'SPY', date: '250321', type: 'C', strike: 0.001)
        expect(occ.strike).to eq(0.001)
        expect(occ.full_id).to eq('SPY   250321C00000001')
      end
    end

    context 'with component strings in canonical form' do
      it 'composes OCC symbol' do
        components = { underlying: "X\s\s\s\s\s", date: '250620', type: 'C', strike: '00050000' }
        full_id = components.values.join
        occ = described_class.build(**components)
        expect(occ.full_id).to eq(full_id)
      end
    end

    context 'with objects' do
      it 'composes OCC symbol' do
        components = { underlying: 'X', date: Date.new(2025, 6, 20), type: :C, strike: 50 }
        occ = described_class.build(**components)
        expect(occ.full_id).to eq("X\s\s\s\s\s250620C00050000")
      end
    end

    context 'with valid inputs' do
      it 'composes OCC symbol with padded underlying' do
        occ = described_class.build(underlying: 'X', date: '250620', type: 'C', strike: 50)
        expect(occ.underlying).to eq('X')
        expect(occ.full_id).to eq('X     250620C00050000')
      end

      it 'composes OCC symbol when date is a Date object' do
        date = Date.new(2026, 1, 16)
        occ = described_class.build(underlying: 'EQX', date: date, type: 'C', strike: 5.5)
        expect(occ.underlying).to eq('EQX')
        expect(occ.date_str).to eq('260116')
        expect(occ.type).to eq('C')
        expect(occ.strike).to eq(5.5)
        expect(occ.full_id).to eq('EQX   260116C00005500')
      end

      it 'composes OCC symbol when date is a string' do
        occ = described_class.build(underlying: 'AAPL', date: '250919', type: 'P', strike: 150)
        expect(occ.underlying).to eq('AAPL')
        expect(occ.date_str).to eq('250919')
        expect(occ.type).to eq('P')
        expect(occ.strike).to eq(150.0)
        expect(occ.full_id).to eq('AAPL  250919P00150000')
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
        expect(occ.full_id).to eq('2DJX  250321C00415300')
      end

      it 'composes OCC symbol with rational strike prices' do
        occ = described_class.build(underlying: 'EQX', date: '260116', type: 'C', strike: Rational(11, 2))
        expect(occ.strike).to eq(5.5)
        expect(occ.full_id).to eq('EQX   260116C00005500')
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
