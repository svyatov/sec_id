# frozen_string_literal: true

module SecId
  # International Securities Identification Number (ISIN) - a 12-character alphanumeric code
  # that uniquely identifies a security globally.
  #
  # Format: 2-letter country code + 9-character NSIN + 1-digit check digit
  #
  # @see https://en.wikipedia.org/wiki/International_Securities_Identification_Number
  #
  # @example Validate an ISIN
  #   SecId::ISIN.valid?('US5949181045')  #=> true
  #
  # @example Restore check digit
  #   SecId::ISIN.restore!('US594918104')  #=> 'US5949181045'
  class ISIN < Base
    # Regular expression for parsing ISIN components.
    ID_REGEX = /\A
      (?<identifier>
        (?<country_code>[A-Z]{2})
        (?<nsin>[A-Z0-9]{9}))
      (?<check_digit>\d)?
    \z/x

    # Country codes that use CUSIP Global Services (CGS) for NSIN assignment.
    CGS_COUNTRY_CODES = Set.new(
      %w[
        US CA AG AI AN AR AS AW BB BL BM BO BQ BR BS BZ CL CO CR CW DM DO EC FM
        GD GS GU GY HN HT JM KN KY LC MF MH MP MX NI PA PE PH PR PW PY SR SV SX
        TT UM UY VC VE VG VI YT
      ]
    ).freeze

    # @return [String, nil] the ISO 3166-1 alpha-2 country code
    attr_reader :country_code

    # @return [String, nil] the National Securities Identifying Number (9 characters)
    attr_reader :nsin

    # @param isin [String] the ISIN string to parse
    def initialize(isin)
      isin_parts = parse isin
      @identifier = isin_parts[:identifier]
      @country_code = isin_parts[:country_code]
      @nsin = isin_parts[:nsin]
      @check_digit = isin_parts[:check_digit]&.to_i
    end

    # @return [Integer] the calculated check digit (0-9)
    # @raise [InvalidFormatError] if the ISIN format is invalid
    def calculate_check_digit
      validate_format_for_calculation!
      mod10(luhn_sum)
    end

    # @return [CUSIP] a new CUSIP instance
    # @raise [InvalidFormatError] if the country code is not a CGS country
    def to_cusip
      raise InvalidFormatError, "'#{country_code}' is not a CGS country code!" unless cgs?

      CUSIP.new(nsin)
    end

    # @return [Boolean] true if the country code is a CGS country
    def cgs?
      CGS_COUNTRY_CODES.include?(country_code)
    end

    private

    # @return [Integer] the Luhn sum
    # @see https://en.wikipedia.org/wiki/Luhn_algorithm
    def luhn_sum
      reversed_id_digits.each_slice(2).reduce(0) do |sum, (even, odd)|
        double_even = (even || 0) * 2
        double_even -= 9 if double_even > 9
        sum + double_even + (odd || 0)
      end
    end

    # @return [Array<Integer>] the reversed digit array
    def reversed_id_digits
      identifier.each_char.flat_map(&method(:char_to_digits)).reverse!
    end
  end
end
