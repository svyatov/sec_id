# frozen_string_literal: true

module SecId
  # Character-to-digit mapping for Luhn algorithm variants.
  # Maps alphanumeric characters to digit arrays for multi-digit expansion.
  # Used by ISIN for check-digit calculation.
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
  # Used by CUSIP, FIGI, SEDOL, LEI, and IBAN for check-digit calculations.
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

  # Base class for securities identifiers that provides a common interface
  # for validation, check-digit calculation, and parsing.
  #
  # Subclasses must implement:
  # - ID_REGEX constant with named capture groups for parsing
  # - initialize method that calls parse and extracts components
  # - calculate_check_digit method (only if has_check_digit? returns true)
  #
  # Subclasses may override:
  # - has_check_digit? to return false for identifiers without check digits (e.g., CIK, OCC)
  # - valid_format? for additional format validation beyond regex matching
  # - to_s for custom string representation
  #
  # @example Implementing a check-digit identifier
  #   class MyIdentifier < Base
  #     ID_REGEX = /\A(?<identifier>[A-Z]{6})(?<check_digit>\d)?\z/x
  #
  #     def initialize(id)
  #       parts = parse(id)
  #       @identifier = parts[:identifier]
  #       @check_digit = parts[:check_digit]&.to_i
  #     end
  #
  #     def calculate_check_digit
  #       validate_format_for_calculation!
  #       mod10(some_algorithm)
  #     end
  #   end
  #
  # @example Implementing a non-check-digit identifier
  #   class SimpleId < Base
  #     def has_check_digit?
  #       false
  #     end
  #   end
  class Base
    # @return [String] the original input after normalization (stripped and uppercased)
    attr_reader :full_number

    # @return [String, nil] the main identifier portion (without check digit)
    attr_reader :identifier

    # @return [Integer, nil] the check digit value
    attr_reader :check_digit

    class << self
      # @param id [String] the identifier to validate
      # @return [Boolean]
      def valid?(id)
        new(id).valid?
      end

      # @param id [String] the identifier to check
      # @return [Boolean]
      def valid_format?(id)
        new(id).valid_format?
      end

      # Restores (calculates) the check digit and returns the full identifier.
      #
      # @param id_without_check_digit [String] identifier without or with incorrect check digit
      # @return [String] the full identifier with correct check digit
      # @raise [InvalidFormatError] if the identifier format is invalid
      def restore!(id_without_check_digit)
        new(id_without_check_digit).restore!
      end

      # @param id [String] the identifier to calculate check digit for
      # @return [Integer, nil] the calculated check digit, or nil if identifier has no check digit
      # @raise [InvalidFormatError] if the identifier format is invalid
      def check_digit(id)
        new(id).calculate_check_digit
      end
    end

    # Subclasses must override this method.
    #
    # @param _sec_id_number [String] the identifier string to parse
    # @raise [NotImplementedError] always raised in base class
    def initialize(_sec_id_number)
      raise NotImplementedError
    end

    # Override in subclasses to return false for identifiers without check digits.
    #
    # @return [Boolean]
    def has_check_digit?
      true
    end

    # @return [Boolean]
    def valid?
      return valid_format? unless has_check_digit?
      return false unless valid_format?

      check_digit == calculate_check_digit
    end

    # Override in subclasses for additional format validation.
    #
    # @return [Boolean]
    def valid_format?
      !identifier.nil?
    end

    # @return [String] the full identifier with correct check digit
    # @raise [InvalidFormatError] if the identifier format is invalid
    def restore!
      @check_digit = calculate_check_digit
      @full_number = to_s
    end

    # Subclasses with check digits must override this method.
    # Returns nil for identifiers without check digits.
    #
    # @return [Integer, nil] the calculated check digit, or nil if identifier has no check digit
    # @raise [NotImplementedError] if has_check_digit? is true but subclass didn't override
    # @raise [InvalidFormatError] if the identifier format is invalid (in subclasses)
    def calculate_check_digit
      raise NotImplementedError if has_check_digit?

      nil
    end

    # @return [String]
    def to_s
      "#{identifier}#{check_digit}"
    end
    alias to_str to_s

    private

    # @raise [InvalidFormatError] if valid_format? returns false
    # @return [void]
    def validate_format_for_calculation!
      return if valid_format?

      raise InvalidFormatError, "#{self.class.name} '#{full_number}' is invalid and check-digit cannot be calculated!"
    end

    # @param sec_id_number [String, #to_s] the identifier to parse
    # @param upcase [Boolean] whether to upcase the input
    # @return [MatchData, Hash] the regex match data or empty hash if no match
    def parse(sec_id_number, upcase: true)
      @full_number = sec_id_number.to_s.strip
      @full_number.upcase! if upcase
      @full_number.match(self.class::ID_REGEX) || {}
    end

    # @return [Array<Integer>] array of digit values
    # @raise [NotImplementedError] always raised in base class
    def id_digits
      raise NotImplementedError
    end

    # @param char [String] single character to convert
    # @return [Integer, Array<Integer>] single digit or array of digits
    def char_to_digits(char)
      SecId::CHAR_TO_DIGITS.fetch(char)
    end

    # @param char [String] single character to convert
    # @return [Integer] numeric value (0-38)
    def char_to_digit(char)
      SecId::CHAR_TO_DIGIT.fetch(char)
    end

    # @param sum [Integer] the sum to calculate check digit from
    # @return [Integer] check digit (0-9)
    def mod10(sum)
      (10 - (sum % 10)) % 10
    end

    # @param number [Integer] number to split
    # @return [Integer] sum of tens and units digits
    def div10mod10(number)
      (number / 10) + (number % 10)
    end

    # @param numeric_string [String] numeric string representation
    # @return [Integer] check digit value (1-98)
    def mod97(numeric_string)
      98 - (numeric_string.to_i % 97)
    end
  end
end
