# frozen_string_literal: true

module SecID
  # Base class for securities identifiers that provides a common interface
  # for validation, normalization, and parsing.
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
    include IdentifierMetadata
    include Normalizable
    include Validatable

    # @return [String] the original input after normalization (stripped and uppercased)
    attr_reader :full_id

    # @return [String, nil] the main identifier portion (without check digit)
    attr_reader :identifier

    # @api private
    def self.inherited(subclass)
      super
      SecID.__send__(:register_identifier, subclass) if subclass.name&.start_with?('SecID::')
    end

    # Subclasses must override this method.
    #
    # @param _sec_id_number [String] the identifier string to parse
    # @raise [NotImplementedError] always raised in base class
    def initialize(_sec_id_number)
      raise NotImplementedError
    end

    private

    # @param sec_id_number [String, #to_s] the identifier to parse
    # @return [MatchData, Hash] the regex match data or empty hash if no match
    def parse(sec_id_number)
      @full_id = sec_id_number.to_s.strip.upcase
      @full_id.match(self.class::ID_REGEX) || {}
    end
  end
end
