# frozen_string_literal: true

require 'set'

module SecId
  # Financial Instrument Global Identifier (FIGI) - a 12-character alphanumeric code
  # that uniquely identifies financial instruments.
  #
  # Format: 2-character prefix + 'G' + 8-character random part + 1-digit check digit
  # Note: FIGI excludes vowels (A, E, I, O, U) from valid characters.
  #
  # @see https://en.wikipedia.org/wiki/Financial_Instrument_Global_Identifier
  #
  # @example Validate a FIGI
  #   SecId::FIGI.valid?('BBG000BLNQ16')  #=> true
  #
  # @example Restore check digit
  #   SecId::FIGI.restore!('BBG000BLNQ1')  #=> 'BBG000BLNQ16'
  class FIGI < Base
    # Regular expression for parsing FIGI components.
    # The third character must be 'G'. Excludes vowels from valid characters.
    ID_REGEX = /\A
      (?<identifier>
        (?<prefix>[B-DF-HJ-NP-TV-Z0-9]{2})
        G
        (?<random_part>[B-DF-HJ-NP-TV-Z0-9]{8}))
      (?<check_digit>\d)?
    \z/x

    # Country-code prefixes that are restricted from use in FIGI.
    RESTRICTED_PREFIXES = Set.new %w[BS BM GG GB GH KY VG]

    # @return [String, nil] the 2-character prefix
    attr_reader :prefix

    # @return [String, nil] the 8-character random part
    attr_reader :random_part

    # Creates a new FIGI instance.
    #
    # @param figi [String] the FIGI string to parse
    def initialize(figi)
      figi_parts = parse figi
      @identifier = figi_parts[:identifier]
      @prefix = figi_parts[:prefix]
      @random_part = figi_parts[:random_part]
      @check_digit = figi_parts[:check_digit]&.to_i
    end

    # Validates the format including restricted prefix check.
    #
    # @return [Boolean] true if format is valid and prefix is not restricted
    def valid_format?
      !identifier.nil? && !RESTRICTED_PREFIXES.include?(prefix)
    end

    # Calculates the check digit using a modified Luhn algorithm.
    #
    # @return [Integer] the calculated check digit (0-9)
    # @raise [InvalidFormatError] if the FIGI format is invalid
    def calculate_check_digit
      validate_format_for_calculation!
      mod10(modified_luhn_sum)
    end

    private

    # https://en.wikipedia.org/wiki/Luhn_algorithm
    #
    # @return [Integer] the modified Luhn sum
    def modified_luhn_sum
      reversed_id_digits.each_with_index.reduce(0) do |sum, (digit, index)|
        digit *= 2 if index.odd?
        sum + div10mod10(digit)
      end
    end

    # @return [Array<Integer>] the identifier digits in reverse order
    def reversed_id_digits
      identifier.each_char.map(&method(:char_to_digit)).reverse!
    end
  end
end
