# frozen_string_literal: true

# v7 deprecation bridge: old check-digit names keep working but warn (U3).
RSpec.describe 'v7 deprecation bridge' do # rubocop:disable RSpec/DescribeClass
  # Returns the block's value with deprecation warnings suppressed.
  def quietly
    original = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = original
  end

  let(:isin) { SecID::ISIN.new('US5949181045') }

  describe 'method aliases (R1, R4 / AE1)' do
    it 'instance #check_digit returns #checksum and warns' do
      expect(quietly { isin.check_digit }).to eq(isin.checksum)
      expect { isin.check_digit }.to output(a_string_including('check_digit', 'checksum', 'v8')).to_stderr
      expect { isin.checksum }.not_to output.to_stderr
    end

    it 'instance #calculate_check_digit returns #calculate_checksum and warns' do
      expect(quietly { isin.calculate_check_digit }).to eq(isin.calculate_checksum)
      expect { isin.calculate_check_digit }
        .to output(a_string_including('calculate_check_digit', 'calculate_checksum', 'v8')).to_stderr
      expect { isin.calculate_checksum }.not_to output.to_stderr
    end

    it 'class .check_digit returns .checksum and warns' do
      expect(quietly { SecID::ISIN.check_digit('US594918104') }).to eq(SecID::ISIN.checksum('US594918104'))
      expect { SecID::ISIN.check_digit('US594918104') }
        .to output(a_string_including('check_digit', 'checksum', 'v8')).to_stderr
      expect { SecID::ISIN.checksum('US594918104') }.not_to output.to_stderr
    end

    it 'class .has_check_digit? returns .has_checksum? and warns' do
      expect(quietly { SecID::ISIN.has_check_digit? }).to eq(SecID::ISIN.has_checksum?)
      expect { SecID::ISIN.has_check_digit? }
        .to output(a_string_including('has_check_digit?', 'has_checksum?', 'v8')).to_stderr
      expect { SecID::ISIN.has_checksum? }.not_to output.to_stderr
    end

    it 'warns on every call (no dedup)' do
      expect { 2.times { isin.check_digit } }.to output(/deprecated.*deprecated/m).to_stderr
    end

    # RBS::Test wraps the aliased method with an instrumentation frame, which shifts the
    # `uplevel: 2` attribution off the external caller — skip under `rake rbs:test`; the
    # assertion holds under a plain spec run.
    it 'attributes the warning to the calling site, not gem internals (uplevel)', :rbs_test_incompatible do
      expect { isin.check_digit }.to output(/#{Regexp.escape(File.basename(__FILE__))}:\d+/).to_stderr
      expect { isin.check_digit }.not_to output(%r{sec_id/(deprecation|concerns/checkable)\.rb}).to_stderr
    end
  end

  describe 'error class alias (R2, R5 / AE2)' do
    it 'is the same class object as InvalidChecksumError' do
      expect(SecID::InvalidCheckDigitError).to equal(SecID::InvalidChecksumError)
    end

    it 'catches a bad-checksum validate! under either name' do
      expect { SecID::ISIN.new('US5949181040').validate! }.to raise_error(SecID::InvalidChecksumError)
      expect { SecID::ISIN.new('US5949181040').validate! }.to raise_error(SecID::InvalidCheckDigitError)
    end
  end

  describe 'dual components key (R3, R6 / AE3)' do
    it 'exposes both :checksum and :check_digit with equal values via to_h' do
      components = isin.to_h[:components]
      expect(components[:checksum]).to eq(5)
      expect(components[:check_digit]).to eq(components[:checksum])
    end

    it 'pattern-matches under both keys binding the same value' do
      isin => { checksum:, check_digit: }
      expect(check_digit).to eq(checksum)
    end

    it 'reads the dual key from the canonical value, emitting no warning' do
      expect { isin.to_h }.not_to output.to_stderr
      expect { isin.deconstruct_keys(nil) }.not_to output.to_stderr
    end

    it 'holds for two-character checksum types' do
      lei = SecID::LEI.new('529900T8BM49AURSDO55')
      iban = SecID::IBAN.new('GB82WEST12345698765432')
      expect(lei.to_h[:components].values_at(:checksum, :check_digit)).to eq([55, 55])
      expect(iban.to_h[:components].values_at(:checksum, :check_digit)).to eq([82, 82])
    end

    it 'mirrors :check_digit onto :checksum for every checksum type' do
      checksum_types = SecID.identifiers.select(&:has_checksum?)
      expect(checksum_types.length).to eq(9)
      checksum_types.each do |klass|
        components = SecID.generate(klass.type_key).to_h[:components]
        expect(components[:check_digit]).to eq(components[:checksum]), "#{klass.short_name} mirror"
        expect(components[:checksum]).not_to be_nil, "#{klass.short_name} checksum"
      end
    end

    it 'reads the dual key with no deprecation warning for every checksum type' do
      SecID.identifiers.select(&:has_checksum?).each do |klass|
        instance = SecID.generate(klass.type_key)
        expect { instance.to_h }.not_to output.to_stderr, "#{klass.short_name} to_h"
        expect { instance.deconstruct_keys(nil) }.not_to output.to_stderr, "#{klass.short_name} deconstruct"
      end
    end
  end
end
