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

    CGS_COUNTRY_CODES = Set.new(
      %w[
        US CA AG AI AN AR AS AW BB BL BM BO BQ BR BS BZ CL CO CR CW DM DO EC FM
        GD GS GU GY HN HT JM KN KY LC MF MH MP MX NI PA PE PH PR PW PY SR SV SX
        TT UM UY VC VE VG VI YT
      ]
    ).freeze

    attr_reader :country_code, :nsin

    def initialize(isin)
      isin_parts = parse isin
      @identifier = isin_parts[:identifier]
      @country_code = isin_parts[:country_code]
      @nsin = isin_parts[:nsin]
      @check_digit = isin_parts[:check_digit]&.to_i
    end

    def calculate_check_digit
      unless valid_format?
        raise InvalidFormatError, "ISIN '#{full_number}' is invalid and check-digit cannot be calculated!"
      end

      mod10(luhn_sum)
    end

    # CUSIP Global Services
    def cgs?
      CGS_COUNTRY_CODES.include?(country_code)
    end

    def to_cusip
      raise InvalidFormatError, "'#{country_code}' is not a CGS country code!" unless cgs?

      CUSIP.new(nsin)
    end

    private

    # https://en.wikipedia.org/wiki/Luhn_algorithm
    def luhn_sum
      reversed_id_digits.each_slice(2).reduce(0) do |sum, (even, odd)|
        double_even = (even || 0) * 2
        double_even -= 9 if double_even > 9
        sum + double_even + (odd || 0)
      end
    end

    def reversed_id_digits
      identifier.each_char.flat_map(&method(:char_to_digits)).reverse!
    end
  end
end
