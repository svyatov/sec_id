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
    it 'registers all 13 identifier types' do
      expected = %i[isin cusip sedol figi lei iban cik occ wkn valoren cei cfi fisn]
      registered = SecID.identifiers.map { |k| k.short_name.downcase.to_sym }
      expect(registered).to eq(expected)
    end
  end
end
