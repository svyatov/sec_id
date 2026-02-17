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

  describe '.inherited auto-registration' do
    it 'registers all 13 identifier types' do
      expected = %i[isin cusip sedol figi lei iban cik occ wkn valoren cei cfi fisn]
      registered = SecID.identifiers.map { |k| k.short_name.downcase.to_sym }
      expect(registered).to eq(expected)
    end
  end
end
