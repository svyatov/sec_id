# frozen_string_literal: true

module SecId
  # CUSIP Entity Identifier (CEI) - a 10-character alphanumeric code that identifies
  # legal entities in the syndicated loan market.
  #
  # Format: 1 alpha + 1 digit + 7 alphanumeric + 1 check digit
  #
  # @see https://www.cusip.com/identifiers.html
  #
  # @example Validate a CEI
  #   SecId::CEI.valid?('A0BCDEFGH1')  #=> true
  class CEI < Base
    # Regular expression for parsing CEI components.
    ID_REGEX = /\A
      (?<identifier>
        (?<prefix>[A-Z])
        (?<numeric>[0-9])
        (?<entity_id>[A-Z0-9]{7}))
      (?<check_digit>\d)?
    \z/x

    # @return [String, nil] the first character (alphabetic)
    attr_reader :prefix

    # @return [String, nil] the second character (numeric)
    attr_reader :numeric

    # @return [String, nil] the 7-character entity identifier
    attr_reader :entity_id

    # @param cei [String] the CEI string to parse
    def initialize(cei)
      cei_parts = parse cei
      @identifier = cei_parts[:identifier]
      @prefix = cei_parts[:prefix]
      @numeric = cei_parts[:numeric]
      @entity_id = cei_parts[:entity_id]
      @check_digit = cei_parts[:check_digit]&.to_i
    end

    # @return [Integer] the calculated check digit (0-9)
    # @raise [InvalidFormatError] if the CEI format is invalid
    def calculate_check_digit
      validate_format_for_calculation!
      mod10(modified_luhn_sum)
    end

    private

    # Same algorithm as CUSIP (Modulus 10 Double Add Double).
    #
    # @return [Integer] the modified Luhn sum
    # @see https://en.wikipedia.org/wiki/Luhn_algorithm
    def modified_luhn_sum
      reversed_id_digits.each_slice(2).reduce(0) do |sum, (even, odd)|
        double_even = (even || 0) * 2
        sum + div10mod10(double_even) + div10mod10(odd || 0)
      end
    end

    # @return [Array<Integer>] the reversed digit array
    def reversed_id_digits
      identifier.each_char.map(&method(:char_to_digit)).reverse!
    end
  end
end
