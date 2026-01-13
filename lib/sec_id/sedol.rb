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
    # Regular expression for parsing SEDOL components.
    # Excludes vowels (A, E, I, O, U) from valid characters.
    ID_REGEX = /\A
      (?<identifier>[0-9BCDFGHJKLMNPQRSTVWXYZ]{6})
      (?<check_digit>\d)?
    \z/x

    # Weights applied to each character position in the check digit calculation.
    CHARACTER_WEIGHTS = [1, 3, 1, 7, 3, 9].freeze

    # Creates a new SEDOL instance.
    #
    # @param sedol [String] the SEDOL string to parse
    def initialize(sedol)
      sedol_parts = parse sedol
      @identifier = sedol_parts[:identifier]
      @check_digit = sedol_parts[:check_digit]&.to_i
    end

    # Calculates the check digit using weighted sum algorithm.
    #
    # @return [Integer] the calculated check digit (0-9)
    # @raise [InvalidFormatError] if the SEDOL format is invalid
    def calculate_check_digit
      validate_format_for_calculation!
      mod10(weighted_sum)
    end

    private

    # NOTE: I know this isn't the most idiomatic Ruby code, but it's the fastest one
    def weighted_sum
      index = 0
      sum = 0

      while index < id_digits.size
        sum += id_digits[index] * CHARACTER_WEIGHTS[index]
        index += 1
      end

      sum
    end

    def id_digits
      @id_digits ||= identifier.each_char.map(&method(:char_to_digit))
    end
  end
end
