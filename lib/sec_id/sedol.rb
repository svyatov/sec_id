# frozen_string_literal: true

module SecID
  # Stock Exchange Daily Official List (SEDOL) - a 7-character alphanumeric code
  # that identifies securities traded on the London Stock Exchange and other UK exchanges.
  #
  # Format: 6-character identifier + 1-digit checksum
  # Note: SEDOL excludes vowels (A, E, I, O, U) to avoid forming words.
  #
  # @see https://en.wikipedia.org/wiki/SEDOL
  #
  # @example Validate a SEDOL
  #   SecID::SEDOL.valid?('B19GKT4')  #=> true
  #
  # @example Calculate checksum
  #   SecID::SEDOL.checksum('B19GKT')  #=> 4
  class SEDOL < Base
    include Checkable
    include Suggestable

    # Human-readable name of the standard.
    FULL_NAME = 'Stock Exchange Daily Official List'
    # Valid length(s) of a normalized identifier.
    ID_LENGTH = 7
    # A representative valid identifier.
    EXAMPLE = 'B0YBKJ7'
    # Pattern matching the identifier's permitted character set.
    VALID_CHARS_REGEX = /\A[0-9BCDFGHJKLMNPQRSTVWXYZ]+\z/

    # Regular expression for parsing SEDOL components.
    # Excludes vowels (A, E, I, O, U) from valid characters.
    ID_REGEX = /\A
      (?<identifier>[0-9BCDFGHJKLMNPQRSTVWXYZ]{6})
      (?<checksum>\d)?
    \z/x

    # Weights applied to each character position in the checksum calculation.
    CHARACTER_WEIGHTS = [1, 3, 1, 7, 3, 9].freeze

    # Characters valid in a SEDOL body (alphanumeric excluding vowels).
    GENERATE_CHARSET = ALPHANUMERIC.grep(VALID_CHARS_REGEX).freeze

    # @param sedol [String] the SEDOL string to parse
    def initialize(sedol)
      sedol_parts = parse sedol
      @identifier = sedol_parts[:identifier]
      @checksum = sedol_parts[:checksum]&.to_i
    end

    # Valid country codes for SEDOL to ISIN conversion.
    ISIN_COUNTRY_CODES = Set.new(%w[GB IE GG IM JE FK]).freeze

    # @param country_code [String] the ISO 3166-1 alpha-2 country code (default: 'GB')
    # @return [ISIN] a new ISIN instance with calculated checksum
    # @raise [InvalidFormatError] if the country code is not valid for SEDOL
    def to_isin(country_code = 'GB')
      unless ISIN_COUNTRY_CODES.include?(country_code)
        raise InvalidFormatError, "'#{country_code}' is not a valid SEDOL country code!"
      end

      ISIN.new("#{country_code}00#{restore}").restore!
    end

    # @return [Integer] the calculated checksum (0-9)
    # @raise [InvalidFormatError] if the SEDOL format is invalid
    def calculate_checksum
      validate_format_for_calculation!
      mod10(weighted_sum)
    end

    # Generates a random SEDOL body: 6 characters excluding vowels.
    #
    # @param random [Random] source of randomness
    # @return [String] a 6-character SEDOL body without checksum
    def self.generate_body(random)
      random_string(GENERATE_CHARSET, 6, random: random)
    end
    private_class_method :generate_body

    private

    # @return [Hash]
    def components = { checksum: }

    # NOTE: Not idiomatic Ruby, but optimized for performance.
    #
    # @return [Integer] the weighted sum
    def weighted_sum
      index = 0
      sum = 0

      while index < id_digits.size
        sum += id_digits[index] * CHARACTER_WEIGHTS[index]
        index += 1
      end

      sum
    end

    # @return [Array<Integer>] array of digit values
    def id_digits
      @id_digits ||= identifier.each_char.map { |c| CHAR_TO_DIGIT.fetch(c) }
    end
  end
end
