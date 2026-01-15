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
    # Regular expression for parsing WKN components.
    # Excludes letters I and O to avoid confusion with 1 and 0.
    ID_REGEX = /\A
      (?<identifier>[0-9A-HJ-NP-Z]{6})
    \z/x

    # @param wkn [String] the WKN string to parse
    def initialize(wkn)
      wkn_parts = parse(wkn)
      @identifier = wkn_parts[:identifier]
      @check_digit = nil
    end

    # @return [Boolean] always false
    def has_check_digit?
      false
    end
  end
end
