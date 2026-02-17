# frozen_string_literal: true

require 'set'

module SecID
  # Financial Instrument Global Identifier (FIGI) - a 12-character alphanumeric code
  # that uniquely identifies financial instruments.
  #
  # Format: 2-character prefix + 'G' + 8-character random part + 1-digit check digit
  # Note: FIGI excludes vowels (A, E, I, O, U) from valid characters.
  #
  # @see https://en.wikipedia.org/wiki/Financial_Instrument_Global_Identifier
  #
  # @example Validate a FIGI
  #   SecID::FIGI.valid?('BBG000BLNQ16')  #=> true
  #
  # @example Restore check digit
  #   SecID::FIGI.restore!('BBG000BLNQ1')  #=> #<SecID::FIGI>
  class FIGI < Base
    include Checkable

    FULL_NAME = 'Financial Instrument Global Identifier'
    ID_LENGTH = 12
    EXAMPLE = 'BBG000BLNNH6'
    VALID_CHARS_REGEX = /\A[B-DF-HJ-NP-TV-Z0-9]+\z/

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

    # @param figi [String] the FIGI string to parse
    def initialize(figi)
      figi_parts = parse figi
      @identifier = figi_parts[:identifier]
      @prefix = figi_parts[:prefix]
      @random_part = figi_parts[:random_part]
      @check_digit = figi_parts[:check_digit]&.to_i
    end

    # @return [Integer] the calculated check digit (0-9)
    # @raise [InvalidFormatError] if the FIGI format is invalid
    def calculate_check_digit
      validate_format_for_calculation!
      mod10(luhn_sum_indexed(reversed_digits_single(identifier)))
    end

    private

    # @return [Boolean]
    def valid_format?
      !identifier.nil? && !RESTRICTED_PREFIXES.include?(prefix)
    end

    # @return [Array<Symbol>]
    def format_errors
      return [:invalid_prefix] if identifier && RESTRICTED_PREFIXES.include?(prefix)

      super
    end

    # @param code [Symbol]
    # @return [String]
    def validation_message(code)
      return "Prefix '#{prefix}' is restricted" if code == :invalid_prefix

      super
    end
  end
end
