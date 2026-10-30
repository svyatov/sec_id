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
  #       mod10(luhn_sum_standard(identifier))
  #     end
  #   end
  #
  # @see https://en.wikipedia.org/wiki/Luhn_algorithm
  module Checkable
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

    # ASCII byte lookup avoids allocating a String for each checksum character.
    BYTE_TO_DIGIT = CHAR_TO_DIGIT.transform_keys(&:ord).freeze

    # Decimal expansions reused by LEI and IBAN without allocating replacement strings.
    DECIMAL_VALUES = CHAR_TO_DIGIT.transform_values { |value| value.to_s.freeze }.freeze

    # Doubled decimal digits with their digits summed, for expanded ISIN Luhn.
    LUHN_DOUBLE = [0, 2, 4, 6, 8, 1, 3, 5, 7, 9].freeze

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

    # CUSIP/CEI double the rightmost body character; FIGI starts one position left.
    # Input must already have passed the identifier's ASCII format validation.
    #
    # @param id [String] validated identifier body
    # @param double_first [Boolean] whether to double the rightmost value
    # @return [Integer] the Luhn sum
    def luhn_sum_single(id, double_first: true)
      # @type var id: String
      sum = 0
      double = double_first
      (id.bytesize - 1).downto(0) do |index|
        value = BYTE_TO_DIGIT.fetch(id.getbyte(index))
        value *= 2 if double
        sum += div10mod10(value)
        double = !double
      end
      sum
    end

    # ISIN expands letters into two decimal digits before applying Luhn.
    # A letter consumes two positions, so only a numeric character flips parity.
    #
    # @param id [String] validated identifier body
    # @return [Integer] the Luhn sum
    def luhn_sum_standard(id)
      # @type var id: String
      sum = 0
      double = true
      (id.bytesize - 1).downto(0) do |index|
        value = BYTE_TO_DIGIT.fetch(id.getbyte(index))
        units = value % 10
        sum += double ? LUHN_DOUBLE.fetch(units) : units
        if value >= 10
          tens = value / 10
          sum += double ? tens : LUHN_DOUBLE.fetch(tens)
        else
          double = !double
        end
      end
      sum
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
