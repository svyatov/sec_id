# frozen_string_literal: true

module SecId
  # Committee on Uniform Securities Identification Procedures (CUSIP) - a 9-character
  # alphanumeric code that identifies North American securities.
  #
  # Format: 6-character issuer code (CUSIP-6) + 2-character issue number + 1-digit check digit
  #
  # @see https://en.wikipedia.org/wiki/CUSIP
  #
  # @example Validate a CUSIP
  #   SecId::CUSIP.valid?('037833100')  #=> true
  #
  # @example Convert to ISIN
  #   cusip = SecId::CUSIP.new('037833100')
  #   cusip.to_isin('US')  #=> #<SecId::ISIN>
  class CUSIP < Base
    include Checkable

    FULL_NAME = 'Committee on Uniform Securities Identification Procedures'
    ID_LENGTH = 9
    EXAMPLE = '037833100'
    VALID_CHARS_REGEX = /\A[A-Z0-9*@#]+\z/

    # Regular expression for parsing CUSIP components.
    ID_REGEX = /\A
      (?<identifier>
        (?<cusip6>[A-Z0-9]{5}[A-Z0-9*@#])
        (?<issue>[A-Z0-9*@#]{2}))
      (?<check_digit>\d)?
    \z/x

    # @return [String, nil] the 6-character issuer code
    attr_reader :cusip6

    # @return [String, nil] the 2-character issue number
    attr_reader :issue

    # @param cusip [String] the CUSIP string to parse
    def initialize(cusip)
      cusip_parts = parse cusip
      @identifier = cusip_parts[:identifier]
      @cusip6 = cusip_parts[:cusip6]
      @issue = cusip_parts[:issue]
      @check_digit = cusip_parts[:check_digit]&.to_i
    end

    # @return [Integer] the calculated check digit (0-9)
    # @raise [InvalidFormatError] if the CUSIP format is invalid
    def calculate_check_digit
      validate_format_for_calculation!
      mod10(luhn_sum_double_add_double(reversed_digits_single(identifier)))
    end

    # @param country_code [String] the ISO 3166-1 alpha-2 country code (must be CGS country)
    # @return [ISIN] a new ISIN instance
    # @raise [InvalidFormatError] if the country code is not a CGS country
    def to_isin(country_code)
      unless ISIN::CGS_COUNTRY_CODES.include?(country_code)
        raise(InvalidFormatError, "'#{country_code}' is not a CGS country code!")
      end

      cusip_with_check_digit = "#{identifier}#{check_digit || calculate_check_digit}"
      isin = ISIN.new(country_code + cusip_with_check_digit)
      isin.restore!
      isin
    end

    # @return [Boolean] true if first character is a letter (CINS identifier)
    def cins?
      cusip6[0] < '0' || cusip6[0] > '9'
    end
  end
end
