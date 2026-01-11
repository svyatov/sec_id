# frozen_string_literal: true

module SecId
  # https://en.wikipedia.org/wiki/Legal_Entity_Identifier
  class LEI < Base
    ID_REGEX = /\A
      (?<identifier>
        (?<lou_id>[0-9A-Z]{4})
        (?<reserved>[0-9A-Z]{2})
        (?<entity_id>[0-9A-Z]{12}))
      (?<check_digit>\d{2})?
    \z/x

    attr_reader :lou_id, :reserved, :entity_id

    def initialize(lei)
      lei_parts = parse lei
      @identifier = lei_parts[:identifier]
      @lou_id = lei_parts[:lou_id]
      @reserved = lei_parts[:reserved]
      @entity_id = lei_parts[:entity_id]
      @check_digit = lei_parts[:check_digit]&.to_i
    end

    def calculate_check_digit
      unless valid_format?
        raise InvalidFormatError, "LEI '#{full_number}' is invalid and check-digit cannot be calculated!"
      end

      mod97("#{numeric_identifier}00")
    end

    def to_s
      return full_number unless check_digit

      "#{identifier}#{check_digit.to_s.rjust(2, '0')}"
    end

    private

    def numeric_identifier
      identifier.each_char.map { |char| char_to_digit(char) }.join
    end
  end
end
