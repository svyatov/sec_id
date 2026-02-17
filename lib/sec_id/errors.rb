# frozen_string_literal: true

module SecID
  # Immutable value object representing validation errors for an identifier.
  # Follows Rails/ActiveModel conventions: use {#details} for structured error data
  # and {#messages} for human-readable strings.
  #
  # @example No errors
  #   errors = SecID::Errors.new([])
  #   errors.none?     #=> true
  #   errors.empty?    #=> true
  #   errors.messages  #=> []
  #
  # @example With errors
  #   err = [{ error: :invalid_length, message: "Expected 12 characters, got 5" }]
  #   errors = SecID::Errors.new(err)
  #   errors.none?     #=> false
  #   errors.details   #=> [{ error: :invalid_length, message: "..." }]
  #   errors.messages  #=> ["Expected 12 characters, got 5"]
  class Errors
    # @return [Array<Hash{Symbol => Symbol, String}>] array of error hashes with :error and :message keys
    attr_reader :details

    # @param errors [Array<Hash{Symbol => Symbol, String}>] array of error hashes
    def initialize(errors)
      @details = errors.freeze
      freeze
    end

    # @return [Boolean] true when there are no errors
    def none?
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

    # Yields each error detail hash to the block.
    #
    # @yieldparam detail [Hash{Symbol => Symbol, String}]
    # @return [Enumerator, self]
    def each(&)
      @details.each(&)
    end

    # @return [Array<String>] alias for {#messages}
    def to_a
      messages
    end
  end
end
