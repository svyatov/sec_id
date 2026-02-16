# frozen_string_literal: true

module SecId
  # Legal Entity Identifier (LEI) - a 20-character alphanumeric code that
  # uniquely identifies legal entities participating in financial transactions.
  #
  # Format: 4-character LOU ID + 2-character reserved + 12-character entity ID + 2-digit check digit
  #
  # @see https://en.wikipedia.org/wiki/Legal_Entity_Identifier
  # @see https://www.gleif.org/en/about-lei/iso-17442-the-lei-code-structure
  #
  # @example Validate a LEI
  #   SecId::LEI.valid?('529900T8BM49AURSDO55')  #=> true
  #
  # @example Calculate check digit
  #   SecId::LEI.check_digit('529900T8BM49AURSDO')  #=> 55
  class LEI < Base
    include Checkable

    FULL_NAME = 'Legal Entity Identifier'
    ID_LENGTH = 20
    EXAMPLE = '7LTWFZYICNSX8D621K86'
    VALID_CHARS_REGEX = /\A[0-9A-Z]+\z/

    # Regular expression for parsing LEI components.
    ID_REGEX = /\A
      (?<identifier>
        (?<lou_id>[0-9A-Z]{4})
        (?<reserved>[0-9A-Z]{2})
        (?<entity_id>[0-9A-Z]{12}))
      (?<check_digit>\d{2})?
    \z/x

    # @return [String, nil] the 4-character Local Operating Unit (LOU) identifier
    attr_reader :lou_id

    # @return [String, nil] the 2-character reserved field (typically '00')
    attr_reader :reserved

    # @return [String, nil] the 12-character entity-specific identifier
    attr_reader :entity_id

    # @param lei [String] the LEI string to parse
    def initialize(lei)
      lei_parts = parse lei
      @identifier = lei_parts[:identifier]
      @lou_id = lei_parts[:lou_id]
      @reserved = lei_parts[:reserved]
      @entity_id = lei_parts[:entity_id]
      @check_digit = lei_parts[:check_digit]&.to_i
    end

    # @return [Integer] the calculated 2-digit check digit (1-98)
    # @raise [InvalidFormatError] if the LEI format is invalid
    def calculate_check_digit
      validate_format_for_calculation!
      mod97("#{numeric_identifier}00")
    end

    # @return [String]
    def to_s
      return full_id unless check_digit

      "#{identifier}#{check_digit.to_s.rjust(2, '0')}"
    end

    private

    # @return [Integer]
    def check_digit_width
      2
    end

    # @return [String] the numeric string representation
    def numeric_identifier
      identifier.each_char.map { |char| CHAR_TO_DIGIT.fetch(char) }.join
    end
  end
end
