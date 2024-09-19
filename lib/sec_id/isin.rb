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

    attr_reader :country_code, :nsin

    def initialize(isin)
      isin_parts = parse isin
      @identifier = isin_parts[:identifier]
      @country_code = isin_parts[:country_code]
      @nsin = isin_parts[:nsin]
      @check_digit = isin_parts[:check_digit]&.to_i
    end

    def calculate_check_digit
      return mod10(luhn_sum) if valid_format?

      raise InvalidFormatError, "ISIN '#{full_number}' is invalid and check-digit cannot be calculated!"
    end

    CGS_COUNTRY_CODES = %w[
      US CA KY BM VI VG UM TT SR GS SX VC MF LC KN BL PR PH PW
      MP FM YT MH HT GY GU GD DM CW BQ BZ BS AW AG AI AS AN
    ].freeze

    # CUSIP Global Services
    def cgs?
      CGS_COUNTRY_CODES.include?(country_code)
    end

    def to_cusip
      cgs? or raise(InvalidFormatError, "'#{country_code}' is not a CGS country code!")
      CUSIP.new(nsin)
    end

    private

    # https://en.wikipedia.org/wiki/Luhn_algorithm
    def luhn_sum
      sum = 0

      id_digits.reverse.each_slice(2) do |even, odd|
        double_even = (even || 0) * 2
        double_even -= 9 if double_even > 9
        sum += double_even + (odd || 0)
      end

      sum
    end

    def id_digits
      @id_digits ||= identifier.each_char.flat_map(&method(:char_to_digits))
    end
  end
end
