# frozen_string_literal: true

module SecId
  # https://en.wikipedia.org/wiki/International_Securities_Identification_Number
  class ISIN < Base
    ID_REGEX = /\A
      (?<identifier>
        (?<country_code>[A-Z]{2})
        (?<nsin>[A-Z0-9]{9}))
      (?<check_digit>\d)?
    \z/x

    attr_reader :isin, :country_code, :nsin

    def initialize(isin)
      @isin = isin.to_s.strip.upcase
      isin_parts = @isin.match(ID_REGEX) || {}

      @identifier = isin_parts[:identifier]
      @country_code = isin_parts[:country_code]
      @nsin = isin_parts[:nsin]
      @check_digit = isin_parts[:check_digit].to_i if isin_parts[:check_digit]
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
      @isin = to_s
    end

    def calculate_check_digit
      raise InvalidFormatError, "ISIN '#{isin}' is invalid and check-digit cannot be calculated!" unless valid_format?
      mod_10 luhn_sum
    end

    private

    # https://en.wikipedia.org/wiki/Luhn_algorithm
    def luhn_sum
      sum = 0

      digitized_identifier.reverse.each_slice(2) do |even, odd|
        double_even = (even || 0) * 2
        double_even -= 9 if double_even > 9
        sum += double_even + (odd || 0)
      end

      sum
    end
  end
end
