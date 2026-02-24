# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecID::Detector do
  subject(:detector) { described_class.new(SecID.__send__(:identifier_list)) }

  describe '#call' do
    context 'with single-type detection' do
      {
        isin: %w[US5949181045 JP3435000009],
        cusip: %w[037833100 594918104],
        sedol: %w[B0YBKJ7 0263494],
        figi: %w[BBG000BLNNH6 BBG000B9XRY4],
        lei: %w[7LTWFZYICNSX8D621K86],
        iban: %w[GB29NWBK60161331926819 DE89370400440532013000],
        cei: %w[A0BCDEFGH1],
        occ: ['AAPL  210917C00150000'],
        fisn: ['APPLE INC/SH']
      }.each do |type, examples|
        examples.each do |example|
          it "detects #{example} as #{type}" do
            expect(detector.call(example)).to include(type)
          end
        end
      end
    end

    context 'with EXAMPLE constants' do
      SecID.identifiers.each do |klass|
        it "detects #{klass.short_name} EXAMPLE #{klass.example.inspect}" do
          expected_key = klass.short_name.downcase.to_sym
          expect(detector.call(klass.example)).to include(expected_key)
        end
      end
    end

    context 'with special-char dispatch' do
      it 'routes / to FISN' do
        expect(detector.call('APPLE INC/SH')).to eq([:fisn])
      end

      it 'routes / + space to FISN (slash takes priority over space)' do
        expect(detector.call('APPLE INC/SH SER A')).to eq([:fisn])
      end

      it 'routes space (without /) to OCC' do
        expect(detector.call('AAPL  210917C00150000')).to eq([:occ])
      end

      it 'routes * to CUSIP candidates' do
        expect(detector.call('03783310*') - [:cusip]).to be_empty
      end

      it 'routes @ to CUSIP candidates' do
        expect(detector.call('03783310@') - [:cusip]).to be_empty
      end

      it 'routes # to CUSIP candidates' do
        expect(detector.call('03783310#') - [:cusip]).to be_empty
      end

      it 'returns [] for invalid FISN through slash dispatch' do
        expect(detector.call('/')).to eq([])
      end

      it 'returns [] for invalid OCC through space dispatch' do
        expect(detector.call('AB CD')).to eq([])
      end
    end

    context 'with multi-match collisions' do
      it 'detects 514000 as WKN, Valoren, and CIK' do
        expect(detector.call('514000')).to eq(%i[wkn valoren cik])
      end

      it 'detects 3886335 as Valoren and CIK' do
        expect(detector.call('3886335')).to eq(%i[valoren cik])
      end

      it 'detects ESVUFR as WKN and CFI' do
        expect(detector.call('ESVUFR')).to eq(%i[wkn cfi])
      end

      it 'detects 037833100 as CUSIP, Valoren, and CIK' do
        expect(detector.call('037833100')).to eq(%i[cusip valoren cik])
      end
    end

    context 'with specificity ordering' do
      it 'sorts check-digit types before non-check-digit types' do
        result = detector.call('037833100')
        cusip_idx = result.index(:cusip)
        valoren_idx = result.index(:valoren)
        cik_idx = result.index(:cik)
        expect(cusip_idx).to be < valoren_idx
        expect(cusip_idx).to be < cik_idx
      end

      it 'sorts smaller range before larger range within same group' do
        # WKN (fixed 6) before Valoren (range 5) before CIK (range 10)
        result = detector.call('514000')
        expect(result.index(:wkn)).to be < result.index(:valoren)
        expect(result.index(:valoren)).to be < result.index(:cik)
      end
    end

    context 'with input normalization' do
      it 'strips leading and trailing whitespace' do
        expect(detector.call('  US5949181045  ')).to eq([:isin])
      end

      it 'detects lowercase input' do
        expect(detector.call('us5949181045')).to eq([:isin])
      end

      it 'detects mixed-case input' do
        expect(detector.call('Us5949181045')).to eq([:isin])
      end

      it 'accepts non-string input via to_s' do
        expect(detector.call(514_000)).to eq(%i[wkn valoren cik])
      end
    end

    context 'with nil and blank inputs' do
      it 'returns [] for nil' do
        expect(detector.call(nil)).to eq([])
      end

      it 'returns [] for empty string' do
        expect(detector.call('')).to eq([])
      end

      it 'returns [] for whitespace-only string' do
        expect(detector.call('   ')).to eq([])
      end
    end

    context 'with boundary lengths' do
      it 'detects single digit as CIK (min length 1)' do
        expect(detector.call('5')).to eq([:cik])
      end

      it 'detects 10-digit number as CIK (max length 10)' do
        expect(detector.call('1234567890')).to eq([:cik])
      end

      it 'detects 5-digit number as Valoren and CIK (Valoren min length 5)' do
        expect(detector.call('12345')).to eq(%i[valoren cik])
      end

      it 'returns [] for string exceeding all max lengths' do
        expect(detector.call('A' * 36)).to eq([])
      end
    end

    context 'with wrong check digits' do
      it 'rejects ISIN with wrong check digit' do
        expect(detector.call('US5949181040')).to eq([])
      end

      it 'rejects SEDOL with wrong check digit' do
        expect(detector.call('B0YBKJ0')).to eq([])
      end

      it 'excludes CUSIP but keeps overlapping types for wrong CUSIP check digit' do
        result = detector.call('037833105')
        expect(result).not_to include(:cusip)
        expect(result).to include(:valoren, :cik)
      end

      it 'rejects LEI with wrong check digit' do
        expect(detector.call('5493006MHB84DD0ZWV99')).to eq([])
      end
    end

    context 'with type-specific structural rejection' do
      it 'rejects FIGI with restricted prefix' do
        expect(detector.call('BSG000BLNNH6')).to eq([])
      end

      it 'rejects 12 all-Z characters (ISIN check digit fails, FIGI structure fails)' do
        expect(detector.call('ZZZZZZZZZZZZ')).to eq([])
      end

      it 'rejects 12 all-digit string (ISIN needs country code, FIGI needs consonants)' do
        expect(detector.call('123456789012')).to eq([])
      end
    end

    context 'with non-matching inputs' do
      it 'rejects letters at SEDOL length (vowels fail SEDOL, letters fail CIK/Valoren)' do
        expect(detector.call('INVALID')).to eq([])
      end

      it 'rejects unicode characters' do
        expect(detector.call("\u00C9SVUFR")).to eq([])
      end

      it 'rejects strings with tabs' do
        expect(detector.call("AAPL\t210917C00150000")).to eq([])
      end

      it 'rejects strings with newlines' do
        expect(detector.call("US594\n9181045")).to eq([])
      end

      it 'rejects special characters not accepted by any type' do
        expect(detector.call('ABC$DEF')).to eq([])
      end
    end

    context 'with cache invalidation' do
      # rubocop:disable RSpec/ExampleLength
      it 'recreates detector when a new identifier type is registered' do
        # Warm up the detector cache
        SecID.detect('US5949181045')
        original_detector = SecID.__send__(:detector)

        # Simulate registration of a new type
        stub_class = Class.new(SecID::Base)
        allow(stub_class).to receive_messages(name: 'SecID::STUB', const_defined?: false)
        stub_class.const_set(:ID_LENGTH, 99)
        stub_class.const_set(:VALID_CHARS_REGEX, /\A[A-Z]+\z/)
        SecID.__send__(:register_identifier, stub_class)

        new_detector = SecID.__send__(:detector)
        expect(new_detector).not_to equal(original_detector)
      ensure
        # Clean up: remove stub from registry
        SecID.__send__(:identifier_map).delete(:stub)
        SecID.__send__(:identifier_list).delete(stub_class)
        SecID.instance_variable_set(:@detector, nil)
      end
      # rubocop:enable RSpec/ExampleLength
    end

    context 'with performance' do
      it 'detects within acceptable time' do
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        1000.times { detector.call('US5949181045') }
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        expect(elapsed).to be < 0.1
      end
    end
  end
end
