# frozen_string_literal: true

module SecId
  # Base class for securities identifiers that provides a common interface
  # for validation and parsing.
  #
  # Subclasses must implement:
  # - ID_REGEX constant with named capture groups for parsing
  # - initialize method that calls parse and extracts components
  #
  # Subclasses with check digits should also include the Checkable concern,
  # which provides check-digit validation, calculation, and restoration.
  #
  # @example Implementing a check-digit identifier
  #   class MyIdentifier < Base
  #     include Checkable
  #
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
  #     ID_REGEX = /\A(?<identifier>[A-Z]{6})\z/x
  #
  #     def initialize(id)
  #       parts = parse(id)
  #       @identifier = parts[:identifier]
  #     end
  #   end
  #
  # @example Querying identifier metadata
  #   SecId::ISIN.short_name       #=> "ISIN"
  #   SecId::ISIN.full_name        #=> "International Securities Identification Number"
  #   SecId::ISIN.has_check_digit? #=> true
  class Base
    EXCEPTION_MAP = {
      invalid_check_digit: InvalidCheckDigitError,
      invalid_prefix: InvalidStructureError,
      invalid_category: InvalidStructureError,
      invalid_group: InvalidStructureError,
      invalid_bban: InvalidStructureError,
      invalid_date: InvalidStructureError
    }.freeze

    SEPARATORS = /[\s-]/

    # @return [String] the original input after normalization (stripped and uppercased)
    attr_reader :full_number

    # @return [String, nil] the main identifier portion (without check digit)
    attr_reader :identifier

    # @api private
    def self.inherited(subclass)
      super
      SecId.__send__(:register_identifier, subclass) if subclass.name&.start_with?('SecId::')
    end

    class << self
      # @param id [String] the identifier to validate
      # @return [Boolean]
      def valid?(id)
        new(id).valid?
      end

      # @param id [String] the identifier to validate
      # @return [ValidationResult]
      def validate(id)
        new(id).errors
      end

      # Validates the identifier, raising an exception if invalid.
      #
      # @param id [String] the identifier to validate
      # @return [Base] the identifier instance
      # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
      def validate!(id)
        new(id).validate!
      end

      # Maps an error code symbol to its corresponding exception class.
      #
      # @param code [Symbol]
      # @return [Class]
      def exception_for_error(code)
        EXCEPTION_MAP.fetch(code, InvalidFormatError)
      end

      # Returns the unqualified class name (e.g. "ISIN", "CUSIP").
      #
      # @return [String]
      def short_name
        name.split('::').last
      end

      # Returns the full human-readable standard name.
      #
      # @return [String]
      def full_name
        self::FULL_NAME
      end

      # Returns the fixed length or valid length range for identifiers of this type.
      #
      # @return [Integer, Range]
      def id_length
        self::ID_LENGTH
      end

      # Returns a representative valid identifier string.
      #
      # @return [String]
      def example
        self::EXAMPLE
      end

      # @return [Boolean] true if this identifier type uses a check digit
      def has_check_digit?
        ancestors.include?(SecId::Checkable)
      end

      # Normalizes the identifier to its canonical format.
      #
      # @param id [String, #to_s] the identifier to normalize
      # @return [String] the normalized identifier
      # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
      def normalize(id)
        cleaned = sanitize_for_normalization(id)
        new(cleaned).normalized
      end

      private

      # @param id [String, #to_s] the raw identifier input
      # @return [String] stripped, upcased input with separators removed
      def sanitize_for_normalization(id)
        id.to_s.strip.upcase.gsub(self::SEPARATORS, '')
      end
    end

    # Subclasses must override this method.
    #
    # @param _sec_id_number [String] the identifier string to parse
    # @raise [NotImplementedError] always raised in base class
    def initialize(_sec_id_number)
      raise NotImplementedError
    end

    # @return [Boolean]
    def valid?
      valid_format?
    end

    # Returns a {ValidationResult} with error codes and human-readable messages.
    #
    # @return [ValidationResult]
    def errors
      @errors ||= begin
        err = validation_errors.map { |code| build_error(code, validation_message(code)) }
        ValidationResult.new(err)
      end
    end

    # Validates and returns self if valid, raises an exception otherwise.
    #
    # @return [self]
    # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
    def validate!
      return self if valid?

      detail = errors.details.first
      raise self.class.exception_for_error(detail[:error]), detail[:message]
    end

    # Returns the canonical normalized form of this identifier.
    #
    # @return [String]
    # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
    def normalized
      validate!
      to_s
    end
    alias normalize normalized

    # Normalizes this identifier in place, updating {#full_number}.
    #
    # @return [self]
    # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
    def normalize!
      @full_number = normalized
      self
    end

    # @return [String]
    def to_s
      identifier.to_s
    end
    alias to_str to_s

    private

    # Override in subclasses for additional format validation.
    #
    # @return [Boolean]
    def valid_format?
      !identifier.nil?
    end

    # Returns an array of error code symbols describing why validation failed.
    #
    # @return [Array<Symbol>]
    def validation_errors
      return [] if valid_format?

      format_errors
    end

    # Three-stage fallback for format error detection: length, characters, then structure.
    #
    # @return [Array<Symbol>]
    def format_errors
      return [:invalid_length] unless valid_length?
      return [:invalid_characters] unless valid_characters?

      [:invalid_format]
    end

    # @return [Boolean]
    def valid_length?
      return false if full_number.empty?

      id_length = self.class::ID_LENGTH
      expected = id_length.is_a?(Range) ? id_length : ((id_length - check_digit_width)..id_length)
      expected.cover?(full_number.length)
    end

    # @return [Boolean]
    def valid_characters?
      full_number.match?(self.class::VALID_CHARS_REGEX)
    end

    # @return [Integer] width of the check digit (0 for non-checkable, overridden in Checkable)
    def check_digit_width
      0
    end

    # @param code [Symbol] error code
    # @return [String] human-readable error message
    def validation_message(code)
      case code
      when :invalid_length
        expected = self.class::ID_LENGTH
        "Expected #{expected} characters, got #{full_number.length}"
      when :invalid_characters
        "Contains invalid characters for #{self.class.short_name}"
      when :invalid_format
        "Does not match #{self.class.short_name} format"
      end
    end

    # @param code [Symbol]
    # @param message [String]
    # @return [Hash{Symbol => Symbol, String}]
    def build_error(code, message)
      { error: code, message: message }.freeze
    end

    # @param sec_id_number [String, #to_s] the identifier to parse
    # @return [MatchData, Hash] the regex match data or empty hash if no match
    def parse(sec_id_number)
      @full_number = sec_id_number.to_s.strip.upcase
      @full_number.match(self.class::ID_REGEX) || {}
    end
  end
end
