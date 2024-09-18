# frozen_string_literal: true

require 'set'

module SecId
  class FIGI < Base
    ID_REGEX = /\A
      (?<identifier>
        (?<prefix>[B-DF-HJ-NP-TV-Z0-9]{2})
        G
        (?<random_part>[B-DF-HJ-NP-TV-Z0-9]{8}))
      (?<check_digit>\d)?
    \z/x

    attr_reader :prefix, :random_part

    def initialize(figi)
      figi_parts = parse figi
      @identifier = figi_parts[:identifier]
      @prefix = figi_parts[:prefix]
      @random_part = figi_parts[:random_part]
      @check_digit = figi_parts[:check_digit]&.to_i
    end

    RESTRICTED_PREFIXES = Set.new %w[BS BM GG GB GH KY VG]

    def valid_format?
      !identifier.nil? and !RESTRICTED_PREFIXES.include?(prefix)
    end

    def calculate_check_digit
      return mod10(modified_luhn_sum) if valid_format?

      raise InvalidFormatError, "FIGI '#{full_number}' is invalid and check-digit cannot be calculated!"
    end

    private

    def modified_luhn_sum
      identifier[0, 11].reverse.chars.map.with_index do |char, index|
        value = char_to_digit(char)
        value *= 2 if index.odd?
        value.to_s.chars.map(&:to_i)
      end.flatten.sum
    end
  end
end
