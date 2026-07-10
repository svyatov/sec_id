# frozen_string_literal: true

RSpec.describe SecID::Base do
  describe '#initialize' do
    it 'raises NotImplementedError' do
      expect { described_class.new('test') }.to raise_error(NotImplementedError)
    end
  end

  describe '.error_class_for' do
    it 'maps :invalid_check_digit to InvalidCheckDigitError' do
      expect(described_class.error_class_for(:invalid_check_digit)).to eq(SecID::InvalidCheckDigitError)
    end

    it 'maps :invalid_prefix to InvalidStructureError' do
      expect(described_class.error_class_for(:invalid_prefix)).to eq(SecID::InvalidStructureError)
    end

    it 'maps :invalid_category to InvalidStructureError' do
      expect(described_class.error_class_for(:invalid_category)).to eq(SecID::InvalidStructureError)
    end

    it 'maps :invalid_group to InvalidStructureError' do
      expect(described_class.error_class_for(:invalid_group)).to eq(SecID::InvalidStructureError)
    end

    it 'maps :invalid_bban to InvalidStructureError' do
      expect(described_class.error_class_for(:invalid_bban)).to eq(SecID::InvalidStructureError)
    end

    it 'maps :invalid_date to InvalidStructureError' do
      expect(described_class.error_class_for(:invalid_date)).to eq(SecID::InvalidStructureError)
    end

    it 'defaults unknown codes to InvalidFormatError' do
      expect(described_class.error_class_for(:unknown_code)).to eq(SecID::InvalidFormatError)
    end
  end

  describe 'metadata methods (via ISIN)' do
    it '.short_name returns unqualified class name' do
      expect(SecID::ISIN.short_name).to eq('ISIN')
    end

    it '.full_name returns human-readable name' do
      expect(SecID::ISIN.full_name).to eq('International Securities Identification Number')
    end

    it '.id_length returns the length constant' do
      expect(SecID::ISIN.id_length).to eq(12)
    end

    it '.example returns a representative identifier' do
      expect(SecID::ISIN.example).to eq('US5949181045')
    end

    it '.has_check_digit? returns true for Checkable types' do
      expect(SecID::ISIN.has_check_digit?).to be(true)
    end

    it '.has_check_digit? returns false for non-Checkable types' do
      expect(SecID::CIK.has_check_digit?).to be(false)
    end

    it '.type_key returns the registry symbol' do
      expect(SecID::ISIN.type_key).to eq(:isin)
    end
  end

  describe '.type_key' do
    it 'round-trips through SecID[] for every registered type' do
      SecID.identifiers.each { |klass| expect(SecID[klass.type_key]).to be(klass) }
    end
  end

  describe '.detection_priority' do
    # Mirrors ISIN's check-digit rank and ID_LENGTH so a comparison against ISIN ties on the
    # first two elements and is decided by the third — the only slot that can hold Infinity.
    let(:unregistered) do
      klass = Class.new(described_class) { include SecID::Checkable }
      klass.const_set(:ID_LENGTH, 12)
      klass
    end

    it 'ranks check-digit types ahead of non-check-digit types' do
      expect(SecID::ISIN.detection_priority[0]).to eq(0)
      expect(SecID::CIK.detection_priority[0]).to eq(1)
    end

    it 'uses length_specificity as the second element' do
      expect(SecID::ISIN.detection_priority[1]).to eq(1)
      expect(SecID::BIC.detection_priority[1]).to eq(2)
    end

    it 'uses registration order as the third element' do
      keys = SecID.identifiers.map { |klass| klass.detection_priority[2] }
      expect(keys).to eq((0...SecID.identifiers.size).to_a)
    end

    it 'sorts an unregistered class last without raising' do
      expect(unregistered.detection_priority[2]).to eq(Float::INFINITY)
      expect(unregistered.detection_priority.take(2)).to eq(SecID::ISIN.detection_priority.take(2))
      expect(unregistered.detection_priority <=> SecID::ISIN.detection_priority).to eq(1)
    end

    it 'returns a memoized frozen tuple' do
      expect(SecID::ISIN.detection_priority).to be_frozen.and be(SecID::ISIN.detection_priority)
    end
  end

  describe '#to_h' do
    # Expected symbols are hardcoded, not derived from type_key: comparing to_h[:type]
    # against klass.type_key would be x == x, since to_h returns self.class.type_key.
    it 'emits the registry symbol as the :type value for every registered type' do
      expected = %i[isin cusip sedol figi lei iban cik occ wkn valoren cei cfi fisn bic dti]
      emitted = SecID.identifiers.map { |klass| klass.new(klass.example).to_h[:type] }
      expect(emitted).to eq(expected)
    end
  end

  describe '#deconstruct_keys' do
    # AE1: a valid identifier through SecID.parse destructures to its components.
    it 'binds components from a parsed identifier' do
      case SecID.parse('US5949181045')
      in SecID::ISIN[country_code:, nsin:]
        expect([country_code, nsin]).to eq(%w[US 594918104])
      end
    end

    # AE2: SecID.parse is the validity channel; an invalid check digit yields nil.
    it 'falls to the nil branch for an identifier SecID.parse rejects' do
      matched =
        case SecID.parse('US6949181045')
        in SecID::ISIN then :isin
        in nil then :nil
        end

      expect(matched).to eq(:nil)
    end

    # AE3: the protocol does not gate on valid?.
    it 'destructures an instance with an invalid check digit' do
      isin = SecID::ISIN.new('US6949181045')
      expect(isin).not_to be_valid
      expect(isin.deconstruct_keys(nil)).to eq(country_code: 'US', nsin: '694918104', check_digit: 5)
    end

    # AE4: unparseable input binds nil, mirroring MatchData#deconstruct_keys.
    it 'binds nil for components of unparseable input' do
      case SecID::ISIN.new('GARBAGE')
      in SecID::ISIN[nsin:]
        expect(nsin).to be_nil
      end
    end

    # AE6: Match is a Data, and the identifier it wraps now destructures too.
    it 'destructures nested inside a scan result' do
      match = SecID.extract('holding US5949181045 today').first

      case match
      in { type: :isin, identifier: SecID::ISIN[country_code:] }
        expect(country_code).to eq('US')
      end
    end

    it 'ignores the keys argument' do
      isin = SecID::ISIN.new('US5949181045')
      expect(isin.deconstruct_keys([:country_code])).to eq(isin.deconstruct_keys(nil))
    end

    it 'does not define deconstruct, so array patterns do not match' do
      expect(SecID::ISIN.new('US5949181045')).not_to respond_to(:deconstruct)
      expect do
        case SecID::ISIN.new('US5949181045')
        in SecID::ISIN[_first]
          nil
        end
      end.to raise_error(NoMatchingPatternError)
    end

    it 'returns a fresh hash on every call' do
      isin = SecID::ISIN.new('US5949181045')
      isin.deconstruct_keys(nil)[:country_code] = 'ZZ'
      expect(isin.deconstruct_keys(nil)[:country_code]).to eq('US')
    end

    it 'keeps components private' do
      expect(described_class.private_method_defined?(:components)).to be(true)
    end
  end

  describe '#== / #eql? / #hash' do
    it 'considers same type with same normalized value equal' do
      expect(SecID::ISIN.new('us5949181045')).to eq(SecID::ISIN.new('US5949181045'))
    end

    it 'considers different values not equal' do
      expect(SecID::ISIN.new('US5949181045')).not_to eq(SecID::ISIN.new('US0378331005'))
    end

    it 'considers different types not equal even with overlapping input' do
      expect(SecID::ISIN.new('US5949181045')).not_to eq(SecID::CUSIP.new('US5949181045'))
    end

    it 'considers invalid identifiers with same input equal' do
      a = SecID::ISIN.new('INVALID')
      b = SecID::ISIN.new('INVALID')
      expect(a).to eq(b)
    end

    it 'considers invalid identifiers with different input not equal' do
      expect(SecID::ISIN.new('BAD1')).not_to eq(SecID::ISIN.new('BAD2'))
    end

    it 'has #eql? behave the same as #==' do
      a = SecID::ISIN.new('us5949181045')
      b = SecID::ISIN.new('US5949181045')
      expect(a).to eql(b)
    end

    it 'produces equal #hash for equal instances' do
      a = SecID::ISIN.new('us5949181045')
      b = SecID::ISIN.new('US5949181045')
      expect(a.hash).to eq(b.hash)
    end

    it 'produces different #hash for unequal instances' do
      a = SecID::ISIN.new('US5949181045')
      b = SecID::ISIN.new('US0378331005')
      expect(a.hash).not_to eq(b.hash)
    end

    it 'works as Hash key' do
      a = SecID::ISIN.new('us5949181045')
      b = SecID::ISIN.new('US5949181045')
      hash = { a => 'found' }
      expect(hash[b]).to eq('found')
    end

    it 'works in Set' do
      a = SecID::ISIN.new('us5949181045')
      b = SecID::ISIN.new('US5949181045')
      set = Set[a, b]
      expect(set.size).to eq(1)
    end

    it 'handles CIK leading-zero padding' do
      expect(SecID::CIK.new('1234')).to eq(SecID::CIK.new('0000001234'))
    end
  end

  describe '#as_json' do
    it 'returns the same hash as to_h' do
      isin = SecID::ISIN.new('US5949181045')
      expect(isin.as_json).to eq(isin.to_h)
    end

    it 'works with JSON.generate' do
      require 'json'
      isin = SecID::ISIN.new('US5949181045')
      expect { JSON.generate(isin.as_json) }.not_to raise_error
    end
  end

  describe '.inherited auto-registration' do
    it 'registers all 15 identifier types' do
      expected = %i[isin cusip sedol figi lei iban cik occ wkn valoren cei cfi fisn bic dti]
      registered = SecID.identifiers.map { |k| k.short_name.downcase.to_sym }
      expect(registered).to eq(expected)
    end
  end
end
