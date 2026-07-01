# frozen_string_literal: true

require 'sec_id/active_model'

RSpec.describe SecIdValidator do
  # Builds an anonymous ActiveModel class validating `attribute` with the given `sec_id:` config.
  def model_for(config, attribute: :isin)
    Class.new do
      include ActiveModel::Validations

      attr_accessor attribute

      validates attribute, sec_id: config
      define_singleton_method(:name) { 'Security' }
    end
  end

  # Validates `value` against `config` and returns the populated record.
  def record_for(config, value, attribute: :isin)
    model_for(config, attribute: attribute).new.tap do |record|
      record.public_send("#{attribute}=", value)
      record.validate
    end
  end

  describe 'single type (type:) — AE1, R5, R6' do
    it 'accepts a valid identifier' do
      expect(record_for({ type: :isin }, 'US0378331005')).to be_valid
    end

    it 'rejects an invalid identifier with a single error on the attribute' do
      record = record_for({ type: :isin }, 'US0378331004')

      expect(record).not_to be_valid
      expect(record.errors[:isin].size).to eq(1)
    end
  end

  describe 'fail-fast on misconfiguration — AE2, R6' do
    it 'raises ArgumentError at class definition for an unknown type' do
      expect { model_for({ type: :bogus }) }.to raise_error(ArgumentError, /bogus/)
    end

    it 'raises ArgumentError when both type: and types: are given' do
      expect { model_for({ type: :isin, types: %i[isin cusip] }) }
        .to raise_error(ArgumentError, /either :type or :types/)
    end

    it 'raises ArgumentError for an unknown type inside a types: allowlist' do
      expect { model_for({ types: %i[isin bogus] }) }.to raise_error(ArgumentError, /bogus/)
    end

    it 'raises ArgumentError for an empty types: allowlist' do
      expect { model_for({ types: [] }) }.to raise_error(ArgumentError, /empty/)
    end
  end

  describe 'allowlist (types:) and agnostic — AE3, R7, R8' do
    it 'accepts a value valid as one of the allowlisted types' do
      expect(record_for({ types: %i[isin cusip] }, '037833100')).to be_valid
    end

    it 'rejects a value not valid as any allowlisted type' do
      expect(record_for({ types: %i[isin cusip] }, 'B0YBKJ7')).not_to be_valid
    end

    it 'accepts a valid identifier of any supported type when agnostic' do
      expect(record_for(true, 'B0YBKJ7')).to be_valid
    end
  end

  describe 'strict by default — separators rejected without normalize:' do
    it 'rejects separatored input' do
      expect(record_for({ type: :isin }, 'US-0378331005')).not_to be_valid
    end

    it 'accepts the canonical form' do
      expect(record_for({ type: :isin }, 'US0378331005')).to be_valid
    end
  end

  describe 'error message — part of AE5, R11' do
    it 'reads "is not a valid <TYPE>" for a single type' do
      record = record_for({ type: :isin }, 'US0378331004')

      expect(record.errors.full_messages).to eq(['Isin is not a valid ISIN'])
    end

    it 'reads "is not a valid securities identifier" when agnostic' do
      record = record_for(true, 'not-an-id')

      expect(record.errors.full_messages).to eq(['Isin is not a valid securities identifier'])
    end

    it 'honors a message: override' do
      record = record_for({ type: :isin, message: 'bad' }, 'US0378331004')

      expect(record.errors.full_messages).to eq(['Isin bad'])
    end

    it 'lets an app-defined :sec_id i18n key override the built-in default' do
      I18n.backend.store_translations(
        :en, activemodel: { errors: { models: { security: { attributes: { isin: { sec_id: 'via i18n' } } } } } }
      )
      record = record_for({ type: :isin }, 'US0378331004')

      expect(record.errors.full_messages).to eq(['Isin via i18n'])
    ensure
      I18n.reload!
    end
  end

  describe 'normalize: true — AE4, R9, R10' do
    it 'accepts separatored input and rewrites the attribute to canonical form' do
      record = record_for({ type: :isin, normalize: true }, 'us-0378331005')

      expect(record).to be_valid
      expect(record.isin).to eq('US0378331005')
    end

    it 'leaves an invalid value untouched' do
      record = record_for({ type: :isin, normalize: true }, 'us-0378331004')

      expect(record).not_to be_valid
      expect(record.isin).to eq('us-0378331004')
    end

    it 'writes the canonical form in agnostic mode' do
      record = record_for({ normalize: true }, 'us-0378331005')

      expect(record).to be_valid
      expect(record.isin).to eq('US0378331005')
    end

    it 'writes the canonical form for an allowlist match' do
      record = record_for({ types: %i[isin cusip], normalize: true }, 'us-0378331005')

      expect(record).to be_valid
      expect(record.isin).to eq('US0378331005')
    end
  end

  describe 'non-String attribute values' do
    it 'rejects a non-String value under strict validation' do
      expect(record_for({ type: :isin }, 378_331_005)).not_to be_valid
    end

    it 'rejects a non-String value under normalize without mutating it' do
      record = record_for({ type: :isin, normalize: true }, 378_331_005)

      expect(record).not_to be_valid
      expect(record.isin).to eq(378_331_005)
    end
  end

  describe 'details: true — AE5, R12' do
    it 'names the check-digit reason for a bad-check-digit ISIN' do
      record = record_for({ type: :isin, details: true }, 'US0378331004')

      expect(record.errors[:isin].first).to match(/check digit/i)
    end

    it 'names the length reason for a wrong-length value' do
      record = record_for({ type: :isin, details: true }, 'US03')

      expect(record.errors[:isin].first).to match(/characters/i)
    end

    it 'surfaces the reason in normalize mode too' do
      record = record_for({ type: :isin, details: true, normalize: true }, 'us-0378331004')

      expect(record.errors[:isin].first).to match(/check digit/i)
    end

    it 'falls back to the generic message for an allowlist' do
      record = record_for({ types: %i[isin cusip], details: true }, 'not-an-id')

      expect(record.errors[:isin].first).to eq('is not a valid securities identifier')
    end

    it 'falls back to the generic message when agnostic' do
      record = record_for({ details: true }, 'not-an-id')

      expect(record.errors[:isin].first).to eq('is not a valid securities identifier')
    end
  end

  describe 'standard EachValidator options — R13' do
    it 'skips nil with allow_nil: true' do
      expect(record_for({ type: :isin, allow_nil: true }, nil)).to be_valid
    end

    it 'skips blank with allow_blank: true' do
      expect(record_for({ type: :isin, allow_blank: true }, '')).to be_valid
    end

    it 'still rejects nil without allow_nil' do
      expect(record_for({ type: :isin }, nil)).not_to be_valid
    end
  end
end
