# frozen_string_literal: true

module SecID
  # Unique Product Identifier (UPI, ISO 4914) - a 12-character code that identifies
  # OTC derivative products for regulatory reporting, issued by the ANNA Derivatives
  # Service Bureau.
  #
  # Format: fixed 'QZ' prefix + 9-character body + 1 check character, drawn from a
  # 30-symbol alphabet (digits 0-9 plus consonants; vowels and 'Y' never appear).
  # Validated fully offline via ISO 7064 hybrid MOD 31,30 over the 11 preceding characters.
  #
  # @see https://www.anna-dsb.com
  #
  # @example Validate a UPI
  #   SecID::UPI.valid?('QZRBG6ZTKS42')  #=> true
  #
  # @example Restore check character
  #   SecID::UPI.restore('QZRBG6ZTKS4')  #=> 'QZRBG6ZTKS42'
  class UPI < Base
    include Checkable

    # Human-readable name of the standard.
    FULL_NAME = 'Unique Product Identifier'
    # Valid length of a normalized identifier.
    ID_LENGTH = 12
    # A representative valid identifier.
    EXAMPLE = 'QZRBG6ZTKS42'
    # Pattern matching the identifier's permitted character set (digits + consonants, no vowels/Y).
    VALID_CHARS_REGEX = /\A[0-9B-DF-HJ-NP-TV-XZ]+\z/

    # Regular expression for parsing UPI components: fixed 'QZ' prefix, 9-character body,
    # optional check character.
    ID_REGEX = /\A
      (?<identifier>QZ[0-9B-DF-HJ-NP-TV-XZ]{9})
      (?<checksum>[0-9B-DF-HJ-NP-TV-XZ])?
    \z/x

    # The 30-symbol UPI alphabet, ordered by check-character value (0-29).
    ALPHABET = '0123456789BCDFGHJKLMNPQRSTVWXZ'.chars.freeze

    # Maps each alphabet character to its check-character value (0-29).
    ALPHABET_VALUE = ALPHABET.each_with_index.to_h.freeze

    # Characters valid in a UPI body (same alphabet as VALID_CHARS_REGEX).
    GENERATE_CHARSET = ALPHANUMERIC.grep(VALID_CHARS_REGEX).freeze

    # @param upi [String] the UPI string to parse
    def initialize(upi)
      upi_parts = parse upi
      @identifier = upi_parts[:identifier]
      @checksum = upi_parts[:checksum]
    end

    # @return [String] the calculated check character
    # @raise [InvalidFormatError] if the UPI format is invalid
    def calculate_checksum
      validate_format_for_calculation!
      mod31_30_check_char(identifier, ALPHABET, ALPHABET_VALUE)
    end

    # Generates a random UPI body: the fixed 'QZ' prefix plus 9 characters drawn
    # from the UPI alphabet.
    #
    # @param random [Random] source of randomness
    # @return [String] an 11-character UPI body without check character
    def self.generate_body(random)
      "QZ#{random_string(GENERATE_CHARSET, 9, random: random)}"
    end
    private_class_method :generate_body

    private

    # @return [Hash]
    def components = { checksum: }
  end
end
