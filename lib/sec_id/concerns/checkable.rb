# frozen_string_literal: true

module SecID
  # Provides checksum validation and calculation for securities identifiers.
  # Include this module in classes that have a checksum as part of their format.
  #
  # Including classes must implement:
  # - `calculate_checksum` method that returns the calculated checksum value
  #
  # This module provides:
  # - Character-to-digit mapping constants
  # - Luhn algorithm variants for checksum calculation
  # - `valid?` override that validates format and checksum
  # - `restore` method returning full identifier string without mutation
  # - `restore!` method to calculate and set the checksum, returning `self`
  # - `checksum` attribute
  # - Class-level convenience methods: `restore`, `restore!`, `checksum`
  #
  # @example Including in an identifier class
  #   class MyIdentifier < Base
  #     include Checkable
  #
  #     def calculate_checksum
  #       validate_format_for_calculation!
  #       mod10(luhn_sum_standard(reversed_digits_multi(identifier)))
  #     end
  #   end
  #
  # @see https://en.wikipedia.org/wiki/Luhn_algorithm
  module Checkable
    # Character-to-digit mapping for Luhn algorithm variants.
    # Maps alphanumeric characters to digit arrays for multi-digit expansion.
    # Used by ISIN for checksum calculation.
    CHAR_TO_DIGITS = {
      '0' => 0,      '1' => 1,      '2' => 2,      '3' => 3,      '4' => 4,
      '5' => 5,      '6' => 6,      '7' => 7,      '8' => 8,      '9' => 9,
      'A' => [1, 0], 'B' => [1, 1], 'C' => [1, 2], 'D' => [1, 3], 'E' => [1, 4],
      'F' => [1, 5], 'G' => [1, 6], 'H' => [1, 7], 'I' => [1, 8], 'J' => [1, 9],
      'K' => [2, 0], 'L' => [2, 1], 'M' => [2, 2], 'N' => [2, 3], 'O' => [2, 4],
      'P' => [2, 5], 'Q' => [2, 6], 'R' => [2, 7], 'S' => [2, 8], 'T' => [2, 9],
      'U' => [3, 0], 'V' => [3, 1], 'W' => [3, 2], 'X' => [3, 3], 'Y' => [3, 4], 'Z' => [3, 5],
      '*' => [3, 6], '@' => [3, 7], '#' => [3, 8]
    }.freeze

    # Character-to-digit mapping for single-digit conversion.
    # Maps alphanumeric characters to values 0-38 (A=10, B=11, ..., Z=35, *=36, @=37, #=38).
    # Used by CUSIP, FIGI, SEDOL, LEI, and IBAN for checksum calculations.
    CHAR_TO_DIGIT = {
      '0' => 0,  '1' => 1,  '2' => 2,  '3' => 3,  '4' =>  4,
      '5' => 5,  '6' => 6,  '7' => 7,  '8' => 8,  '9' =>  9,
      'A' => 10, 'B' => 11, 'C' => 12, 'D' => 13, 'E' => 14,
      'F' => 15, 'G' => 16, 'H' => 17, 'I' => 18, 'J' => 19,
      'K' => 20, 'L' => 21, 'M' => 22, 'N' => 23, 'O' => 24,
      'P' => 25, 'Q' => 26, 'R' => 27, 'S' => 28, 'T' => 29,
      'U' => 30, 'V' => 31, 'W' => 32, 'X' => 33, 'Y' => 34, 'Z' => 35,
      '*' => 36, '@' => 37, '#' => 38
    }.freeze

    # Extends the including identifier class with the concern's class methods and checksum reader.
    #
    # @param base [Class] the identifier class including this concern
    # @return [void]
    # @api private
    def self.included(base)
      base.attr_reader :checksum
      base.extend(ClassMethods)
    end

    # Class methods added when Checkable is included.
    module ClassMethods
      # Returns the full identifier string with correct checksum.
      #
      # @param id_without_checksum [String] identifier without or with incorrect checksum
      # @return [String] the full identifier with correct checksum
      # @raise [InvalidFormatError] if the identifier format is invalid
      def restore(id_without_checksum)
        new(id_without_checksum).restore
      end

      # Restores (calculates) the checksum and returns the instance.
      #
      # @param id_without_checksum [String] identifier without or with incorrect checksum
      # @return [self] the restored instance with correct checksum
      # @raise [InvalidFormatError] if the identifier format is invalid
      def restore!(id_without_checksum)
        new(id_without_checksum).restore!
      end

      # @param id [String] the identifier to calculate checksum for
      # @return [Integer, String] the calculated checksum
      # @raise [InvalidFormatError] if the identifier format is invalid
      def checksum(id)
        new(id).calculate_checksum
      end

      # @deprecated Use {.checksum}. Kept as a v7 bridge; removed in v8.
      #
      # @param id [String] the identifier to calculate the checksum for
      # @return [Integer, String] the calculated checksum
      # @raise [InvalidFormatError] if the identifier format is invalid
      def check_digit(id)
        SecID::Deprecation.warn(old: 'check_digit', new: 'checksum')
        checksum(id)
      end
    end

    # Validates format and checksum.
    #
    # @return [Boolean]
    def valid?
      super && checksum == calculate_checksum
    end

    # Returns the full identifier string with correct checksum without mutation.
    #
    # @return [String] the full identifier with correct checksum
    # @raise [InvalidFormatError] if the identifier format is invalid
    def restore
      "#{identifier}#{calculate_checksum.to_s.rjust(checksum_width, '0')}"
    end

    # Calculates and sets the checksum, updating full_id.
    #
    # @return [self]
    # @raise [InvalidFormatError] if the identifier format is invalid
    def restore!
      @checksum = calculate_checksum
      @full_id = to_s
      self
    end

    # Subclasses must override this method to implement their checksum algorithm.
    #
    # @return [Integer, String] the calculated checksum
    # @raise [NotImplementedError] if subclass doesn't implement
    # @raise [InvalidFormatError] if the identifier format is invalid
    def calculate_checksum
      raise NotImplementedError
    end

    # @return [String]
    def to_s
      "#{identifier}#{checksum&.to_s&.rjust(checksum_width, '0')}"
    end

    # @deprecated Use {#checksum}. Kept as a v7 bridge; removed in v8.
    #
    # @return [Integer, String]
    def check_digit
      SecID::Deprecation.warn(old: 'check_digit', new: 'checksum')
      checksum
    end

    # @deprecated Use {#calculate_checksum}. Kept as a v7 bridge; removed in v8.
    #
    # @return [Integer, String]
    # @raise [InvalidFormatError] if the identifier format is invalid
    def calculate_check_digit
      SecID::Deprecation.warn(old: 'calculate_check_digit', new: 'calculate_checksum')
      calculate_checksum
    end

    private

    # CUSIP/CEI style: "Double Add Double" algorithm.
    # Processes pairs of digits, doubling the first (even-positioned from right),
    # then summing both digit's div10mod10 values.
    #
    # @param digits [Array<Integer>] reversed array of digit values
    # @return [Integer] the Luhn sum
    def luhn_sum_double_add_double(digits)
      digits.each_slice(2).reduce(0) do |sum, (even, odd)|
        double_even = (even || 0) * 2
        sum + div10mod10(double_even) + div10mod10(odd || 0)
      end
    end

    # FIGI style: index-based doubling algorithm.
    # Doubles odd-indexed digits (from right), then sums div10mod10 values.
    #
    # @param digits [Array<Integer>] reversed array of digit values
    # @return [Integer] the Luhn sum
    def luhn_sum_indexed(digits)
      digits.each_with_index.reduce(0) do |sum, (digit, index)|
        digit *= 2 if index.odd?
        sum + div10mod10(digit)
      end
    end

    # ISIN style: standard Luhn with subtract-9 for values > 9.
    # Processes pairs of digits, doubling the first (even-positioned from right),
    # subtracting 9 if result > 9.
    #
    # @param digits [Array<Integer>] reversed array of digit values
    # @return [Integer] the Luhn sum
    def luhn_sum_standard(digits)
      digits.each_slice(2).reduce(0) do |sum, (even, odd)|
        double_even = (even || 0) * 2
        double_even -= 9 if double_even > 9
        sum + double_even + (odd || 0)
      end
    end

    # Converts identifier characters to reversed digit array using single-digit mapping.
    # Used by CUSIP, CEI, FIGI, and SEDOL.
    #
    # @param id [String] the identifier string
    # @return [Array<Integer>] reversed array of digit values
    def reversed_digits_single(id)
      id.each_char.map { |c| CHAR_TO_DIGIT.fetch(c) }.reverse!
    end

    # Converts identifier characters to reversed digit array using multi-digit mapping.
    # Used by ISIN where letters expand to two digits.
    #
    # @param id [String] the identifier string
    # @return [Array<Integer>] reversed array of digit values
    def reversed_digits_multi(id)
      id.each_char.flat_map { |c| CHAR_TO_DIGITS.fetch(c) }.reverse!
    end

    # Returns error codes including checksum validation.
    #
    # @return [Array<Symbol>]
    def error_codes
      return detect_errors unless valid_format?
      return [:invalid_checksum] unless checksum == calculate_checksum

      []
    end

    # @return [Integer]
    def checksum_width
      1
    end

    # @param code [Symbol]
    # @return [String]
    def validation_message(code)
      if code == :invalid_checksum
        fmt = ->(cd) { cd.to_s.rjust(checksum_width, '0') }
        return "Checksum '#{fmt[checksum]}' is invalid, expected '#{fmt[calculate_checksum]}'"
      end

      super
    end

    # @raise [InvalidFormatError] if valid_format? returns false
    # @return [void]
    def validate_format_for_calculation!
      return if valid_format?

      raise InvalidFormatError, "#{self.class.name} '#{full_id}' is invalid and checksum cannot be calculated!"
    end

    # @param sum [Integer] the sum to calculate checksum from
    # @return [Integer] checksum (0-9)
    def mod10(sum)
      (10 - (sum % 10)) % 10
    end

    # @param number [Integer] number to split
    # @return [Integer] sum of tens and units digits
    def div10mod10(number)
      (number / 10) + (number % 10)
    end

    # @param numeric_string [String] numeric string representation
    # @return [Integer] checksum value (1-98)
    def mod97(numeric_string)
      98 - (numeric_string.to_i % 97)
    end

    # ISO 7064 hybrid MOD 31,30 check character over a base string, parameterized
    # by the type's 30-symbol alphabet. Shared by DTI and UPI.
    #
    # @param base [String] the base string (identifier without check character)
    # @param alphabet [Array<String>] the 30-symbol alphabet ordered by check value (0-29)
    # @param alphabet_value [Hash{String => Integer}] maps each alphabet character to its value
    # @return [String] the single computed check character
    def mod31_30_check_char(base, alphabet, alphabet_value)
      perm = 30
      base.each_char do |c|
        s = (perm + alphabet_value.fetch(c)) % 30
        s = 30 if s.zero?
        perm = (s * 2) % 31
      end
      alphabet.fetch((31 - perm) % 30)
    end
  end
end
