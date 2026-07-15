# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecID::Suggestable do
  describe 'AE1: homoglyph fix plus checksum fallback' do
    subject(:suggestions) { SecID::ISIN.suggest('US5949181O45') }

    it 'returns the O->0 homoglyph substitution as a :high candidate' do
      fix = suggestions.find { |s| s.edit == :substitution && s.position == 9 }
      expect(fix).to have_attributes(from: 'O', to: '0', confidence: :high, to_s: 'US5949181045')
    end

    it 'ranks the always-present :checksum recompute candidate last' do
      expect(suggestions.last.edit).to eq(:checksum)
    end
  end

  describe 'AE3: check-character typo yields a :checksum candidate ranked last' do
    subject(:suggestions) { SecID::ISIN.suggest('US5949181046') } # body correct, check 6 should be 5

    it 'includes a :checksum candidate with the recomputed check character' do
      checksum = suggestions.find { |s| s.edit == :checksum }
      expect(checksum).to have_attributes(position: nil, from: '6', to: '5', confidence: nil, to_s: 'US5949181045')
    end

    it 'ranks the :checksum candidate last' do
      expect(suggestions.last.edit).to eq(:checksum)
    end
  end

  describe 'AE2: multiple plausible edits ranked :high, :medium, then :checksum' do
    subject(:suggestions) { SecID::ISIN.suggest('US5499181045') } # 9<->4 transposed at index 3

    it 'returns substitutions before transpositions before the checksum fallback' do
      grouped = suggestions.map(&:edit).chunk_while { |a, b| a == b }.map(&:first)
      expect(grouped).to eq(%i[substitution transposition checksum])
    end

    it 'includes the reverting adjacent transposition tagged :medium' do
      transposition = suggestions.find { |s| s.edit == :transposition }
      expect(transposition).to have_attributes(position: 3, from: '49', to: '94', confidence: :medium)
    end

    it 'places every :high candidate before every :medium candidate' do
      last_high = suggestions.rindex { |s| s.confidence == :high }
      first_medium = suggestions.index { |s| s.confidence == :medium }
      expect(last_high).to be < first_medium
    end
  end

  describe 'AE4: no structural parse returns an empty Array' do
    it 'returns [] for wrong-length input' do
      expect(SecID::ISIN.suggest('US594')).to eq([])
    end

    it 'returns [] for illegal-charset input' do
      expect(SecID::ISIN.suggest('US5949181@45')).to eq([])
    end
  end

  describe 'already-valid input' do
    it 'returns [] (nothing to repair)' do
      expect(SecID::ISIN.suggest('US5949181045')).to eq([])
    end
  end

  describe 'missing checksum character (nil check field)' do
    # Input typed without its check character: valid_format? passes (the checksum is
    # optional for the length check) but valid? fails, so the bodies are equal and the
    # :checksum candidate renders an empty `from` (there was no check character to correct).
    it 'yields a :checksum candidate with an empty from' do
      checksum = SecID::ISIN.suggest('US594918104').find { |s| s.edit == :checksum }
      expect(checksum).to have_attributes(position: nil, from: '', to: '5', to_s: 'US5949181045')
    end
  end

  describe 'coincidental exclusion (no :low tier)' do
    # Corrupt 4->7 (not a homoglyph pair) so the only body fix is the coincidental
    # revert; it must NOT be suggested — only the :checksum fallback survives.
    subject(:suggestions) { SecID::CUSIP.suggest('7P3JNSEN6') } # valid is 4P3JNSEN6

    it 'never returns the non-homoglyph revert substitution' do
      revert = suggestions.find { |s| s.edit == :substitution && s.position.zero? && s.to == '4' }
      expect(revert).to be_nil
    end

    it 'still returns the :checksum fallback (never empty for structurally-valid input)' do
      expect(suggestions.map(&:edit)).to include(:checksum)
    end
  end

  describe 'transposition tagging' do
    it 'tags an adjacent-swap fix :transposition / :medium' do
      transposition = SecID::ISIN.suggest('US5499181045').find { |s| s.edit == :transposition }
      expect(transposition.confidence).to eq(:medium)
    end
  end

  describe 'LEI (two-character checksum)' do
    # A single substitution cannot reach both check digits; restore supplies the candidate.
    it 'repairs a wrong two-digit check via the :checksum candidate' do
      lei = SecID::LEI.generate(random: Random.new(1)).to_s
      wrong = lei[18, 2] == '00' ? '11' : '00'
      suggestions = SecID::LEI.suggest("#{lei[0, 18]}#{wrong}")
      checksum = suggestions.find { |s| s.edit == :checksum }
      expect(checksum).to have_attributes(position: nil, to: lei[18, 2], confidence: nil)
      expect(checksum.to_s).to eq(lei)
    end
  end

  describe 'IBAN (mid-string checksum)' do
    it 'yields a :checksum candidate for a wrong check field' do
      suggestions = SecID::IBAN.suggest('DE00370400440532013000')
      checksum = suggestions.find { |s| s.edit == :checksum }
      expect(checksum).to have_attributes(position: nil, from: '00', to: '89', confidence: nil)
      expect(checksum.to_s).to eq('DE89370400440532013000')
    end

    it 'filters out country-code edits that re-segment the BBAN boundary' do
      # D->0 in the country code is a homoglyph but re-segments; valid? rejects it.
      expect(SecID::IBAN.suggest('0E89370400440532013000')).to eq([])
    end
  end

  describe 'DTI (alphabetic check, vowel-free alphabet)' do
    it 'returns an in-charset homoglyph fix (S<->5) plus the :checksum fallback' do
      suggestions = SecID::DTI.suggest('C5T3S80PV') # valid is CST3S80PV (5 at index 1 should be S)
      fix = suggestions.find { |s| s.edit == :substitution && s.position == 1 }
      expect(fix).to have_attributes(from: '5', to: 'S', confidence: :high, to_s: 'CST3S80PV')
      expect(suggestions.last.edit).to eq(:checksum)
    end

    it 'returns only the :checksum fallback for an out-of-charset (O-for-0) typo' do
      # 'O' is not in the DTI alphabet: the whole string fails valid_format? -> [].
      expect(SecID::DTI.suggest('OST3S80PV')).to eq([])
    end
  end

  describe 'property: across all 9 checksum types' do
    checksum_types = %i[isin cusip sedol figi lei iban cei dti upi]

    checksum_types.each do |key|
      context "when repairing #{key}" do
        let(:klass) { SecID[key] }
        let(:valid) { klass.generate(random: Random.new(42)).to_s }
        # A homoglyph-reachable, format-valid but checksum-failing body typo. Since HOMOGLYPHS is
        # bidirectional, the engine must revert it back to `valid` — except IBAN, whose all-numeric
        # BBAN and numeric check admit no in-format letter/digit homoglyph.
        let(:homoglyph_typo) do
          candidates = valid.each_char.with_index.flat_map do |char, index|
            SecID::Suggestable::HOMOGLYPHS.fetch(char, []).map { |rep| valid.dup.tap { |m| m[index] = rep } }
          end
          candidates.find { |c| klass.new(c).then { |id| !id.valid? && id.send(:valid_format?) } }
        end
        # For IBAN (no homoglyph body fix), fall back to any format-valid checksum-failing typo.
        let(:corrupted) do
          homoglyph_typo || begin
            candidates = valid.each_char.with_index.flat_map do |char, index|
              ((('0'..'9').to_a + ('A'..'Z').to_a) - [char]).map { |rep| valid.dup.tap { |m| m[index] = rep } }
            end
            candidates.find { |c| klass.new(c).then { |id| !id.valid? && id.send(:valid_format?) } } ||
              raise("no mutation for #{klass}")
          end
        end
        let(:suggestions) { klass.suggest(corrupted) }

        it 'returns only valid, correctly-tiered candidates with the checksum fallback last', :aggregate_failures do
          expect(suggestions).not_to be_empty
          expect(suggestions).to all(satisfy { |s| s.identifier.valid? })
          expect(suggestions.map(&:confidence)).to all(satisfy { |c| [:high, :medium, nil].include?(c) })
          body_edits = suggestions.reject { |s| s.edit == :checksum }
          expect(body_edits.map(&:confidence)).to all(satisfy { |c| %i[high medium].include?(c) })
          # A homoglyph typo must actually be reverted: the original identifier is among the body edits
          # (guards against silently broken homoglyph/transposition generation — the :checksum fallback
          # alone would otherwise satisfy every assertion above).
          expect(body_edits.map(&:to_s)).to include(valid) if homoglyph_typo
          expect(suggestions.last.edit).to eq(:checksum)
        end
      end
    end
  end
end
