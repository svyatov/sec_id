# frozen_string_literal: true

module SecID
  # Provides validation methods for identifier types.
  #
  # Including classes should override `#valid_format?` and optionally `#detect_errors`
  # for type-specific validation.
  module Validatable
    ERROR_MAP = {
      invalid_check_digit: InvalidCheckDigitError,
      invalid_prefix: InvalidStructureError,
      invalid_category: InvalidStructureError,
      invalid_group: InvalidStructureError,
      invalid_bban: InvalidStructureError,
      invalid_date: InvalidStructureError
    }.freeze

    # @api private
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods added when Validatable is included.
    module ClassMethods
      # @param id [String] the identifier to validate
      # @return [Boolean]
      def valid?(id)
        new(id).valid?
      end

      # Validates the identifier and returns the instance (with errors cached).
      #
      # @param id [String] the identifier to validate
      # @return [Base] the identifier instance
      def validate(id)
        new(id).validate
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
      def error_class_for(code)
        ERROR_MAP.fetch(code, InvalidFormatError)
      end
    end

    # @return [Boolean]
    def valid?
      valid_format?
    end

    # Eagerly triggers validation and caches errors.
    #
    # @return [self]
    def validate
      errors
      self
    end

    # Returns an {Errors} object with error codes and human-readable messages.
    #
    # @return [Errors]
    def errors
      return @errors if defined?(@errors)

      @errors = Errors.new(error_codes.map { |code| build_error(code, validation_message(code)) })
    end

    # Validates and returns self if valid, raises an exception otherwise.
    #
    # @return [self]
    # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
    def validate!
      return self if valid?

      detail = errors.details.first
      raise error_class_for(detail[:error]), detail[:message]
    end

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
    def error_codes
      return [] if valid_format?

      detect_errors
    end

    # Three-stage fallback for format error detection: length, characters, then structure.
    #
    # @return [Array<Symbol>]
    def detect_errors
      return [:invalid_length] unless valid_length?
      return [:invalid_characters] unless valid_characters?

      [:invalid_format]
    end

    # @return [Boolean]
    def valid_length?
      return false if full_id.empty?

      id_length = self.class::ID_LENGTH
      expected = id_length.is_a?(Range) ? id_length : ((id_length - check_digit_width)..id_length)
      expected.cover?(full_id.length)
    end

    # @return [Boolean]
    def valid_characters?
      full_id.match?(self.class::VALID_CHARS_REGEX)
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
        "Expected #{expected} characters, got #{full_id.length}"
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
  end
end
