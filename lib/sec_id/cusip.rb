# frozen_string_literal: true

module SecId
  # https://en.wikipedia.org/wiki/CUSIP
  class CUSIP < Base
    ID_REGEX = /\A
      (?<identifier>
        (?<cusip6>[A-Z0-9]{5}[A-Z0-9*@#])
        (?<issue>[A-Z0-9*@#]{2}))
      (?<check_digit>\d)?
    \z/x.freeze

    attr_reader :cusip6, :issue

    def initialize(cusip)
      cusip_parts = parse cusip
      @identifier = cusip_parts[:identifier]
      @cusip6 = cusip_parts[:cusip6]
      @issue = cusip_parts[:issue]
      @check_digit = cusip_parts[:check_digit]&.to_i
    end

    def calculate_check_digit
      return mod_10(modified_luhn_sum) if valid_format?

      raise InvalidFormatError, "CUSIP '#{full_number}' is invalid and check-digit cannot be calculated!"
    end

    private

    # https://en.wikipedia.org/wiki/Luhn_algorithm
    def modified_luhn_sum
      sum = 0

      id_digits.reverse.each_slice(2) do |even, odd|
        double_even = (even || 0) * 2
        sum += div_10_mod_10(double_even) + div_10_mod_10(odd || 0)
      end

      sum
    end

    def id_digits
      @id_digits ||= identifier.each_char.map(&method(:char_to_digit))
    end
  end
end
