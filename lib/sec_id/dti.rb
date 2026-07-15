# frozen_string_literal: true

module SecID
  # Digital Token Identifier (DTI, ISO 24165) - a 9-character alphanumeric code
  # that identifies digital tokens (e.g. cryptocurrencies) for regulatory reporting.
  #
  # Format: 8-character base + 1 check character, drawn from a 30-symbol alphabet
  # (digits 0-9 plus consonants; vowels and 'Y' never appear). Validated fully offline
  # via ISO 7064 hybrid MOD 31,30 over the base.
  #
  # @see https://www.dtif.org
  #
  # @example Validate a DTI
  #   SecID::DTI.valid?('X9J9K872S')  #=> true
  #
  # @example Restore checksum
  #   SecID::DTI.restore('X9J9K872')  #=> 'X9J9K872S'
  class DTI < Base
    include Checkable
    include Suggestable

    # Human-readable name of the standard.
    FULL_NAME = 'Digital Token Identifier'
    # Valid length(s) of a normalized identifier.
    ID_LENGTH = 9
    # A representative valid identifier.
    EXAMPLE = 'X9J9K872S'
    # Pattern matching the identifier's permitted character set (digits + consonants, no vowels/Y).
    VALID_CHARS_REGEX = /\A[0-9B-DF-HJ-NP-TV-XZ]+\z/

    # Regular expression for parsing DTI components. First character of the base
    # is never '0'.
    ID_REGEX = /\A
      (?<identifier>
        [1-9B-DF-HJ-NP-TV-XZ]
        [0-9B-DF-HJ-NP-TV-XZ]{7})
      (?<checksum>[0-9B-DF-HJ-NP-TV-XZ])?
    \z/x

    # The 30-symbol DTI alphabet, ordered by check-character value (0-29).
    ALPHABET = '0123456789BCDFGHJKLMNPQRSTVWXZ'.chars.freeze

    # Maps each alphabet character to its check-character value (0-29).
    ALPHABET_VALUE = ALPHABET.each_with_index.to_h.freeze

    # Characters valid in a DTI base (same alphabet as VALID_CHARS_REGEX).
    GENERATE_CHARSET = ALPHANUMERIC.grep(VALID_CHARS_REGEX).freeze

    # Registry-assigned codes whose stored check character differs from the
    # algorithmic ISO 7064 MOD 31,30 computation. Base (8 chars) => registered code (9 chars).
    #
    # @see https://www.dtif.org
    GRANDFATHERED_CODES = { '4H95J0R2' => '4H95J0R2X' }.freeze

    # @param dti [String] the DTI string to parse
    def initialize(dti)
      dti_parts = parse dti
      @identifier = dti_parts[:identifier]
      @checksum = dti_parts[:checksum]
    end

    # @return [String] the calculated or grandfathered check character
    # @raise [InvalidFormatError] if the DTI format is invalid
    def calculate_checksum
      validate_format_for_calculation!
      grandfathered_checksum(identifier) || iso7064_mod31_30_check_char(identifier)
    end

    # Generates a random DTI body: first character non-zero, 8 characters total,
    # all drawn from the DTI alphabet.
    #
    # @param random [Random] source of randomness
    # @return [String] an 8-character DTI body without check character
    def self.generate_body(random)
      first = random_string(GENERATE_CHARSET - ['0'], 1, random: random)
      "#{first}#{random_string(GENERATE_CHARSET, 7, random: random)}"
    end
    private_class_method :generate_body

    private

    # @return [Hash]
    def components = { checksum: }

    # @param base [String] the 8-character DTI base
    # @return [String, nil] the registered check character, or nil if not grandfathered
    def grandfathered_checksum(base)
      GRANDFATHERED_CODES[base]&.delete_prefix(base)
    end

    # ISO 7064 hybrid MOD 31,30 check character over an 8-character base.
    #
    # @param base [String] the 8-character DTI base
    # @return [String] the single computed check character
    def iso7064_mod31_30_check_char(base)
      mod31_30_check_char(base, ALPHABET, ALPHABET_VALUE)
    end
  end
end
