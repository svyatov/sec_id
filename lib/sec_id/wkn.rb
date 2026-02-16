# frozen_string_literal: true

module SecId
  # Wertpapierkennnummer (WKN) - a 6-character alphanumeric code
  # used to identify securities in Germany.
  #
  # Format: 6 alphanumeric characters (excluding I and O)
  # Note: WKN excludes letters I and O to avoid confusion with 1 and 0.
  #
  # @see https://en.wikipedia.org/wiki/Wertpapierkennnummer
  #
  # @example Validate a WKN
  #   SecId::WKN.valid?('514000')  #=> true
  #   SecId::WKN.valid?('CBK100')  #=> true
  class WKN < Base
    FULL_NAME = 'Wertpapierkennnummer'
    ID_LENGTH = 6
    EXAMPLE = '514000'
    VALID_CHARS_REGEX = /\A[0-9A-HJ-NP-Z]+\z/

    # Regular expression for parsing WKN components.
    # Excludes letters I and O to avoid confusion with 1 and 0.
    ID_REGEX = /\A
      (?<identifier>[0-9A-HJ-NP-Z]{6})
    \z/x

    # @param wkn [String] the WKN string to parse
    def initialize(wkn)
      wkn_parts = parse(wkn)
      @identifier = wkn_parts[:identifier]
    end

    # @param country_code [String] the ISO 3166-1 alpha-2 country code (default: 'DE')
    # @return [ISIN] a new ISIN instance with calculated check digit
    # @raise [InvalidFormatError] if the country code is not DE
    # @raise [InvalidFormatError] if the WKN format is invalid
    def to_isin(country_code = 'DE')
      raise InvalidFormatError, "'#{country_code}' is not a valid WKN country code!" unless country_code == 'DE'
      raise InvalidFormatError, "WKN '#{full_id}' is invalid!" unless valid_format?

      isin = ISIN.new("#{country_code}000#{identifier}")
      isin.restore!
      isin
    end
  end
end
