# frozen_string_literal: true

module SecId
  # Stock Exchange Daily Official List (SEDOL) - a 7-character alphanumeric code
  # that identifies securities traded on the London Stock Exchange and other UK exchanges.
  #
  # Format: 6-character identifier + 1-digit check digit
  # Note: SEDOL excludes vowels (A, E, I, O, U) to avoid forming words.
  #
  # @see https://en.wikipedia.org/wiki/SEDOL
  #
  # @example Validate a SEDOL
  #   SecId::SEDOL.valid?('B19GKT4')  #=> true
  #
  # @example Calculate check digit
  #   SecId::SEDOL.check_digit('B19GKT')  #=> 4
  class SEDOL < Base
    include Checkable

    # Regular expression for parsing SEDOL components.
    # Excludes vowels (A, E, I, O, U) from valid characters.
    ID_REGEX = /\A
      (?<identifier>[0-9BCDFGHJKLMNPQRSTVWXYZ]{6})
      (?<check_digit>\d)?
    \z/x

    # Weights applied to each character position in the check digit calculation.
    CHARACTER_WEIGHTS = [1, 3, 1, 7, 3, 9].freeze

    # @param sedol [String] the SEDOL string to parse
    def initialize(sedol)
      sedol_parts = parse sedol
      @identifier = sedol_parts[:identifier]
      @check_digit = sedol_parts[:check_digit]&.to_i
    end

    # Valid country codes for SEDOL to ISIN conversion.
    ISIN_COUNTRY_CODES = Set.new(%w[GB IE GG IM JE FK]).freeze

    # @param country_code [String] the ISO 3166-1 alpha-2 country code (default: 'GB')
    # @return [ISIN] a new ISIN instance with calculated check digit
    # @raise [InvalidFormatError] if the country code is not valid for SEDOL
    def to_isin(country_code = 'GB')
      unless ISIN_COUNTRY_CODES.include?(country_code)
        raise InvalidFormatError, "'#{country_code}' is not a valid SEDOL country code!"
      end

      restore!
      isin = ISIN.new("#{country_code}00#{full_number}")
      isin.restore!
      isin
    end

    # @return [Integer] the calculated check digit (0-9)
    # @raise [InvalidFormatError] if the SEDOL format is invalid
    def calculate_check_digit
      validate_format_for_calculation!
      mod10(weighted_sum)
    end

    private

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
