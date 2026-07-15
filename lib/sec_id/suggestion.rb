# frozen_string_literal: true

module SecID
  # Immutable value object representing one repair candidate returned by `suggest`.
  #
  # Carries the corrected, re-validated identifier plus the what-changed diff (edit
  # kind, position, from/to characters) and a confidence tier — the honest surface
  # that keeps a candidate from reading as an authoritative correction.
  #
  # Coordinate system by edit kind:
  # - `:substitution` — `position` is the 0-based index of the changed character;
  #   `from`/`to` are the single characters before/after.
  # - `:transposition` — `position` is the left index of the swapped pair;
  #   `from`/`to` are the two-character adjacent substring before/after the swap.
  # - `:checksum` — `position` is `nil`; `from`/`to` are the old/new check-character
  #   string. `confidence` is `nil` (it is the fallback hypothesis, ranked last).
  #
  # @!attribute [r] type
  #   @return [Symbol] the identifier type key (e.g. :isin)
  # @!attribute [r] identifier
  #   @return [SecID::Base] the valid, parsed corrected identifier
  # @!attribute [r] edit
  #   @return [Symbol] :substitution, :transposition, or :checksum
  # @!attribute [r] position
  #   @return [Integer, nil] the edit position (nil for :checksum)
  # @!attribute [r] from
  #   @return [String] the original character(s)
  # @!attribute [r] to
  #   @return [String] the replacement character(s)
  # @!attribute [r] confidence
  #   @return [Symbol, nil] :high (homoglyph), :medium (transposition), or nil (:checksum)
  #
  # @example
  #   suggestion = SecID::ISIN.suggest('US5949181O45').first
  #   suggestion.to_s          #=> 'US5949181045'
  #   suggestion.edit          #=> :substitution
  #   suggestion.confidence    #=> :high
  Suggestion = Data.define(:type, :identifier, :edit, :position, :from, :to, :confidence)

  # Reopened to add the domain enumerations and serialization helpers per the repo
  # convention (see {Base#as_json}).
  class Suggestion
    # The edit kinds `edit` can take, in rank order (see {Suggestable::RANK}).
    EDIT_KINDS = %i[substitution transposition checksum].freeze

    # The non-nil confidence tiers `confidence` can take; `:checksum` candidates carry `nil`.
    CONFIDENCE_LEVELS = %i[high medium].freeze

    # Returns a JSON-compatible hash representation of the suggestion.
    #
    # @return [Hash] the symbol-keyed field hash (JSON-compatible)
    def as_json(*)
      to_h
    end

    # Returns the corrected identifier as a string.
    #
    # @return [String] the corrected identifier string
    def to_s
      identifier.to_s
    end
  end
end
