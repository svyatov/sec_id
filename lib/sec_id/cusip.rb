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

    VALID_COUNTRY_CODES_FOR_CONVERSION_TO_ISIN = %w[US CA].freeze

    attr_reader :cusip, :cusip6, :issue

    def initialize(cusip)
      @cusip = cusip.to_s.strip.upcase
      cusip_parts = @cusip.match(ID_REGEX) || {}

      @identifier = cusip_parts[:identifier]
      @cusip6 = cusip_parts[:cusip6]
      @issue = cusip_parts[:issue]
      @check_digit = cusip_parts[:check_digit].to_i if cusip_parts[:check_digit]
    end

    def valid?
      return false unless valid_format?

      check_digit == calculate_check_digit
    end

    def valid_format?
      identifier ? true : false
    end

    def restore!
      @check_digit = calculate_check_digit
      @cusip = to_s
    end

    def calculate_check_digit
      return mod_10(modified_luhn_sum) if valid_format?

      raise InvalidFormatError, "CUSIP '#{cusip}' is invalid and check-digit cannot be calculated!"
    end

    private

    # https://en.wikipedia.org/wiki/Luhn_algorithm
    def modified_luhn_sum
      sum = 0

      digitized_identifier.reverse.each_slice(2) do |even, odd|
        double_even = (even || 0) * 2
        double_even -= 9 if double_even > 9
        sum += div_10_mod_10(double_even) + div_10_mod_10(odd || 0)
      end

      sum
    end

    def digitized_identifier
      @digitized_identifier ||= identifier.each_char.map(&method(:char_to_digit))
    end

    def div_10_mod_10(number)
      (number / 10) + (number % 10)
    end
  end
end
