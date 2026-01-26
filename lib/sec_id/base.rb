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
  class Base
    # @return [String] the original input after normalization (stripped and uppercased)
    attr_reader :full_number

    # @return [String, nil] the main identifier portion (without check digit)
    attr_reader :identifier

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

    # Override in subclasses for additional format validation.
    #
    # @return [Boolean]
    def valid_format?
      !identifier.nil?
    end

    # @return [String]
    def to_s
      identifier.to_s
    end
    alias to_str to_s

    private

    # @param sec_id_number [String, #to_s] the identifier to parse
    # @param upcase [Boolean] whether to upcase the input
    # @return [MatchData, Hash] the regex match data or empty hash if no match
    def parse(sec_id_number, upcase: true)
      @full_number = sec_id_number.to_s.strip
      @full_number.upcase! if upcase
      @full_number.match(self.class::ID_REGEX) || {}
    end
  end
end
