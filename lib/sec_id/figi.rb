# frozen_string_literal: true

require 'set'

module SecID
  class FIGI < Base
    ID_REGEX = /\A
      (?<identifier>
        (?<prefix>[B-DF-HJ-NP-TV-Z0-9]{2})
        G
        (?<random_part>[B-DF-HJ-NP-TV-Z0-9]{8}))
      (?<check_digit>\d)?
    \z/x

    RESTRICTED_PREFIXES = Set.new %w[BS BM GG GB GH KY VG]

    attr_reader :prefix, :random_part

    def initialize(figi)
      figi_parts = parse figi
      @identifier = figi_parts[:identifier]
      @prefix = figi_parts[:prefix]
      @random_part = figi_parts[:random_part]
      @check_digit = figi_parts[:check_digit]&.to_i
    end

    def valid_format?
      !identifier.nil? && !RESTRICTED_PREFIXES.include?(prefix)
    end

    def calculate_check_digit
      unless valid_format?
        raise InvalidFormatError, "FIGI '#{full_number}' is invalid and check-digit cannot be calculated!"
      end

      mod10(modified_luhn_sum)
    end

    private

    # https://en.wikipedia.org/wiki/Luhn_algorithm
    def modified_luhn_sum
      reversed_id_digits.each_with_index.reduce(0) do |sum, (digit, index)|
        digit *= 2 if index.odd?
        sum + digit.divmod(10).sum
      end
    end

    def reversed_id_digits
      identifier.each_char.map(&method(:char_to_digit)).reverse!
    end
  end
end
