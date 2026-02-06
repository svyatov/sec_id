# frozen_string_literal: true

module SecId
  # Immutable value object representing the result of identifier validation.
  # Contains a list of errors (if any), each with a code and human-readable message.
  #
  # @example Valid result
  #   result = SecId::ValidationResult.new([])
  #   result.valid?       #=> true
  #   result.errors       #=> []
  #   result.error_codes  #=> []
  #
  # @example Invalid result
  #   errors = [{ code: :invalid_length, message: "Expected 12 characters, got 5" }]
  #   result = SecId::ValidationResult.new(errors)
  #   result.valid?       #=> false
  #   result.error_codes  #=> [:invalid_length]
  class ValidationResult
    # @return [Array<Hash{Symbol => Symbol, String}>] array of error hashes with :code and :message keys
    attr_reader :errors

    # @param errors [Array<Hash{Symbol => Symbol, String}>] array of error hashes
    def initialize(errors)
      @errors = errors.freeze
      freeze
    end

    # @return [Boolean] true when there are no errors
    def valid?
      @errors.empty?
    end

    # @return [Array<Symbol>] error code symbols
    def error_codes
      @errors.map { |e| e[:code] }
    end

    # @return [Array<Hash{Symbol => Symbol, String}>] alias for errors
    def to_a
      @errors
    end
  end
end
