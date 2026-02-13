# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecId::Detector do
  subject(:detector) { described_class.new(SecId.__send__(:identifier_list)) }

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
      SecId.identifiers.each do |klass|
        it "detects #{klass.short_name} EXAMPLE #{klass.example.inspect}" do
          expected_key = klass.short_name.downcase.to_sym
          expect(detector.call(klass.example)).to include(expected_key)
        end
      end
    end

    context 'with fast-dispatch paths' do
      it 'routes / to FISN only' do
        result = detector.call('APPLE INC/SH')
        expect(result).to eq([:fisn])
      end

      it 'routes space (without /) to OCC only' do
        result = detector.call('AAPL  210917C00150000')
        expect(result).to eq([:occ])
      end

      it 'routes * to CUSIP candidates only' do
        # * triggers special_types dispatch — only CUSIP accepts *@#
        # Even if the check digit is wrong, the dispatch path is tested
        result = detector.call('03783310*')
        # Either detects as CUSIP (if check digit matches) or returns []
        expect(result - [:cusip]).to be_empty
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

    context 'with edge cases' do
      it 'returns [] for nil' do
        expect(detector.call(nil)).to eq([])
      end

      it 'returns [] for empty string' do
        expect(detector.call('')).to eq([])
      end

      it 'returns [] for whitespace-only string' do
        expect(detector.call('   ')).to eq([])
      end

      it 'detects lowercase input' do
        expect(detector.call('us5949181045')).to include(:isin)
      end

      it 'returns [] for very long string' do
        expect(detector.call('A' * 36)).to eq([])
      end

      it 'detects single digit as CIK' do
        expect(detector.call('5')).to eq([:cik])
      end
    end

    context 'with no-match inputs' do
      it 'returns [] for INVALID (vowels reject SEDOL, letters reject CIK/Valoren)' do
        expect(detector.call('INVALID')).to eq([])
      end

      it 'returns [] for 12 Z characters (ISIN check digit fails, FIGI rejects structure)' do
        expect(detector.call('ZZZZZZZZZZZZ')).to eq([])
      end

      it 'returns [] for LEI with wrong check digit' do
        expect(detector.call('5493006MHB84DD0ZWV99')).to eq([])
      end
    end

    context 'with performance' do
      it 'detects within acceptable time' do
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        1000.times { detector.call('US5949181045') }
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        expect(elapsed).to be < 1.0
      end
    end
  end
end
