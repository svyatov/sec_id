# frozen_string_literal: true

module SecID
  # Repair engine for checksum-failing identifiers: enumerates plausible single-character
  # edits (homoglyph/OCR substitutions and adjacent transpositions), keeps only those that
  # re-validate, and returns them as confidence-ranked {Suggestion} objects.
  #
  # Included by the 9 checksum types. The candidate space is the human-error net —
  # {HOMOGLYPHS} plus adjacent transpositions — never a full coincidental net. `valid?`
  # is the oracle, so no checksum-invalid candidate ever escapes (a valid candidate is not
  # necessarily the intended correction); the {HOMOGLYPHS} table bounds recall.
  #
  # @see SecID::Suggestion
  #
  # @example
  #   SecID::ISIN.suggest('US5949181O45')
  #   #=> [#<SecID::Suggestion edit=:substitution ...>, #<SecID::Suggestion edit=:checksum ...>]
  module Suggestable
    # Homoglyph / OCR confusion table (KTD5 seed): each character maps to the characters
    # it is commonly mistyped as or misread from. A bidirectional expansion of the seed
    # pairs {0/O, 0/Q, 0/D, 1/I, 1/L, I/L, 2/Z, 5/S, 6/G, 8/B}. Membership bounds recall —
    # widen it (see benchmark/suggest_precision.rb) to raise it.
    HOMOGLYPHS = {
      '0' => %w[O Q D], 'O' => %w[0], 'Q' => %w[0], 'D' => %w[0],
      '1' => %w[I L], 'I' => %w[1 L], 'L' => %w[1 I],
      '2' => %w[Z], 'Z' => %w[2], '5' => %w[S], 'S' => %w[5],
      '6' => %w[G], 'G' => %w[6], '8' => %w[B], 'B' => %w[8]
    }.freeze

    # Rank weight per edit kind: body substitutions first, then adjacent transpositions,
    # then the checksum-recompute fallback last (R6/R7).
    RANK = { substitution: 0, transposition: 1, checksum: 2 }.freeze

    # Extends the including identifier class with the concern's class methods.
    #
    # @param base [Class] the identifier class including this concern
    # @return [void]
    # @api private
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods added when Suggestable is included.
    module ClassMethods
      # Returns confidence-ranked repair candidates for a checksum-failing identifier.
      #
      # @param str [String] the identifier string to repair
      # @return [Array<Suggestion>] ranked candidates; empty when `str` is already valid
      #   or fails the type's format (wrong length or charset)
      def suggest(str)
        new(str).suggest
      end
    end

    # Enumerates plausible edits and returns the re-validating ones, confidence-ranked.
    #
    # @return [Array<Suggestion>] ranked candidates; empty when already valid or unparseable
    def suggest
      return [] if valid?
      return [] unless valid_format?

      surviving = candidate_strings.uniq.map { |candidate| self.class.new(candidate) }.select(&:valid?)
      surviving.filter_map { |candidate| classify(candidate) }.sort_by { |suggestion| RANK.fetch(suggestion.edit) }
    end

    private

    # Homoglyph substitutions + adjacent transpositions + the checksum recompute (R4, R6).
    #
    # @return [Array<String>] candidate identifier strings (unfiltered, may include duplicates)
    def candidate_strings
      homoglyph_candidates + transposition_candidates + [restore]
    end

    # @return [Array<String>]
    def homoglyph_candidates
      full_id.each_char.with_index.flat_map do |char, index|
        Array(HOMOGLYPHS[char]).map { |replacement| replace_at(full_id, index, replacement) }
      end
    end

    # @return [Array<String>]
    def transposition_candidates
      (0...(full_id.length - 1)).filter_map do |index|
        swap_at(full_id, index) unless full_id[index] == full_id[index + 1]
      end
    end

    # @param str [String]
    # @param index [Integer]
    # @param char [String] the replacement character
    # @return [String]
    def replace_at(str, index, char)
      str.dup.tap { |copy| copy[index] = char }
    end

    # @param str [String]
    # @param index [Integer] left index of the adjacent pair to swap
    # @return [String]
    def swap_at(str, index)
      str.dup.tap { |copy| copy[index], copy[index + 1] = copy[index + 1], copy[index] }
    end

    # Tags a surviving candidate by comparing bodies then diffing the strings (KTD3):
    # equal bodies mean only the check characters changed.
    #
    # @param candidate [SecID::Base] a re-validated candidate instance
    # @return [Suggestion, nil] nil when the diff is neither a single substitution nor an adjacent swap
    def classify(candidate)
      return checksum_suggestion(candidate) if candidate.identifier == identifier

      changed = changed_indices(candidate)
      case changed.size
      when 1 then substitution_suggestion(candidate, changed.first.to_i)
      when 2 then transposition_suggestion(candidate, changed)
      end
    end

    # @param candidate [SecID::Base]
    # @return [Array<Integer>] indices where the candidate's string differs from the input's
    def changed_indices(candidate)
      other = candidate.full_id
      (0...full_id.length).reject { |index| full_id[index] == other[index] }
    end

    # @param candidate [SecID::Base]
    # @param index [Integer]
    # @return [Suggestion]
    def substitution_suggestion(candidate, index)
      Suggestion.new(
        type: self.class.type_key, identifier: candidate, edit: :substitution,
        position: index, from: full_id[index].to_s, to: candidate.full_id[index].to_s, confidence: :high
      )
    end

    # @param candidate [SecID::Base]
    # @param indices [Array<Integer>] the two differing indices
    # @return [Suggestion, nil] nil unless the two indices are an adjacent, mutual swap
    def transposition_suggestion(candidate, indices)
      left = indices.min.to_i
      right = indices.max.to_i
      return unless right == left + 1 && swap?(candidate, left, right)

      Suggestion.new(
        type: self.class.type_key, identifier: candidate, edit: :transposition,
        position: left, from: full_id[left, 2].to_s, to: candidate.full_id[left, 2].to_s, confidence: :medium
      )
    end

    # @param candidate [SecID::Base]
    # @param left [Integer]
    # @param right [Integer]
    # @return [Boolean] true when the two positions are a mutual swap of the input's characters
    def swap?(candidate, left, right)
      full_id[left] == candidate.full_id[right] && full_id[right] == candidate.full_id[left]
    end

    # @param candidate [SecID::Base]
    # @return [Suggestion]
    def checksum_suggestion(candidate)
      Suggestion.new(
        type: self.class.type_key, identifier: candidate, edit: :checksum, position: nil,
        from: rendered_checksum(checksum), to: rendered_checksum(candidate.checksum), confidence: nil
      )
    end

    # @param value [Integer, String, nil] a checksum value
    # @return [String] the check-character string, zero-padded to the checksum width ('' when absent)
    def rendered_checksum(value)
      value.nil? ? '' : value.to_s.rjust(checksum_width, '0')
    end
  end
end
