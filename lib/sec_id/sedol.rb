# frozen_string_literal: true

module SecId
  # https://en.wikipedia.org/wiki/SEDOL
  class SEDOL < Base
    ID_REGEX = /\A
      (?<identifier>[0-9BCDFGHJKLMNPQRSTVWXYZ]{6})
      (?<check_digit>\d)?
    \z/x.freeze

    CHARACTER_WEIGHTS = [1, 3, 1, 7, 3, 9].freeze

    attr_reader :full_number

    def initialize(sedol)
      sedol_parts = parse sedol
      @identifier = sedol_parts[:identifier]
      @check_digit = sedol_parts[:check_digit]&.to_i
    end

    def calculate_check_digit
      return mod_10(weighted_sum) if valid_format?

      raise InvalidFormatError, "SEDOL '#{full_number}' is invalid and check-digit cannot be calculated!"
    end

    private

    # NOTE: I know this isn't the most idiomatic Ruby code, but it's the fastest one
    def weighted_sum
      index = 0
      sum = 0

      while index < digitized_identifier.size
        sum += digitized_identifier[index] * CHARACTER_WEIGHTS[index]
        index += 1
      end

      sum
    end

    def digitized_identifier
      @digitized_identifier ||= identifier.each_char.map(&method(:char_to_digit))
    end
  end
end
