# frozen_string_literal: true

module SecId
  # Immutable value object representing the result of identifier validation.
  # Follows Rails/ActiveModel conventions: use {#details} for structured error data
  # and {#messages} for human-readable strings.
  #
  # @example Valid result
  #   result = SecId::ValidationResult.new([])
  #   result.valid?    #=> true
  #   result.empty?    #=> true
  #   result.messages  #=> []
  #
  # @example Invalid result
  #   errors = [{ error: :invalid_length, message: "Expected 12 characters, got 5" }]
  #   result = SecId::ValidationResult.new(errors)
  #   result.valid?    #=> false
  #   result.details   #=> [{ error: :invalid_length, message: "..." }]
  #   result.messages  #=> ["Expected 12 characters, got 5"]
  class ValidationResult
    # @return [Array<Hash{Symbol => Symbol, String}>] array of error hashes with :error and :message keys
    attr_reader :details

    # @param errors [Array<Hash{Symbol => Symbol, String}>] array of error hashes
    def initialize(errors)
      @details = errors.freeze
      freeze
    end

    # @return [Boolean] true when there are no errors
    def valid?
      @details.empty?
    end

    # @return [Array<String>] human-readable error messages
    def messages
      @details.map { |e| e[:message] }
    end

    # @return [Boolean] true when there are errors
    def any?
      !@details.empty?
    end

    # @return [Boolean] true when there are no errors
    def empty?
      @details.empty?
    end

    # @return [Integer] number of errors
    def size
      @details.size
    end

    # @return [Array<String>] alias for {#messages}
    def to_a
      messages
    end
  end
end
