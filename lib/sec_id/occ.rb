# frozen_string_literal: true

require 'date'

module SecId
  # OCC Option Symbol - standardized option symbol format used by Option Clearing Corporation.
  # Format: 6-char underlying (padded) + 6-char date (YYMMDD) + type (C/P) + 8-digit strike (in mills).
  # OCC does not have a check digit, but validates that the date is parseable.
  #
  # @see https://en.wikipedia.org/wiki/Option_symbol#The_OCC_Option_Symbol
  # @see https://web.archive.org/web/20120507220143/http://www.theocc.com/components/docs/initiatives/symbology/symbology_initiative_v1_8.pdf
  #
  # @example Validate an OCC symbol
  #   SecId::OCC.valid?('AAPL  210917C00150000')  #=> true
  #
  # @example Build an OCC symbol from components
  #   occ = SecId::OCC.build(underlying: 'AAPL', date: '2021-09-17', type: 'C', strike: 150.0)
  #   occ.to_s  #=> 'AAPL  210917C00150000'
  class OCC < Base
    # Regular expression for parsing OCC symbol components.
    ID_REGEX = /\A
      (?<initial>
        (?=.{1,6})(?<underlying>\d?[A-Z]{1,5}\d?)(?<padding>[ ]*))
      (?<date>\d{6})
      (?<type>[CP])
      (?<strike_mills>\d{8})
    \z/x

    # @return [String, nil] the underlying security symbol (1-6 chars)
    attr_reader :underlying

    # @return [String, nil] the expiration date string in YYMMDD format
    attr_reader :date_str

    # @return [String, nil] the option type ('C' for call, 'P' for put)
    attr_reader :type

    # Creates a new OCC instance.
    #
    # @param symbol [String] the OCC symbol string to parse
    def initialize(symbol)
      symbol_parts = parse(symbol)
      @initial = symbol_parts[:initial]
      @underlying = symbol_parts[:underlying]
      @date_str = symbol_parts[:date]
      @type = symbol_parts[:type]
      @strike_mills = symbol_parts[:strike_mills]
      # Set identifier for Base compatibility
      @identifier = @initial
    end

    # OCC does not have a check digit.
    #
    # @return [Boolean] always false for OCC
    def has_check_digit?
      false
    end

    # Parses the date string into a Date object.
    #
    # @return [Date, nil] the parsed date or nil if invalid
    def date
      return @date if @date

      @date = Date.strptime(date_str, '%y%m%d') if date_str
    rescue Date::Error
      nil
    end
    alias date_obj date

    # Returns the strike price in dollars.
    #
    # @return [Float] the strike price
    def strike
      @strike ||= @strike_mills.to_i / 1000.0
    end

    # OCC is valid if format matches AND date is parseable.
    #
    # @return [Boolean] true if the OCC symbol is valid
    def valid?
      valid_format? && !date.nil?
    end

    def valid_format?
      !@initial.nil?
    end

    # Normalizes the OCC symbol to canonical format.
    #
    # @return [String] the normalized OCC symbol
    # @raise [InvalidFormatError] if the OCC symbol is invalid
    def normalize!
      raise InvalidFormatError, "OCC '#{full_number}' is invalid and cannot be normalized!" unless valid?

      @strike_mills.length > 8 && @strike_mills = format('%08d', @strike_mills.to_i)
      @initial.length < 6 && @initial = underlying.ljust(6, "\s")

      @full_number = "#{@initial}#{date_str}#{type}#{@strike_mills}"
    end

    # Returns the string representation of the OCC symbol.
    #
    # @return [String] the OCC symbol string
    def to_s
      full_number
    end
    alias to_str to_s

    # Alias for backward compatibility.
    #
    # @return [String] the full OCC symbol
    def full_symbol
      full_number
    end

    class << self
      # Normalizes an OCC symbol to canonical format.
      #
      # @param id [String] the OCC symbol to normalize
      # @return [String] the normalized OCC symbol
      # @raise [InvalidFormatError] if the OCC symbol is invalid
      def normalize!(id)
        new(id).normalize!
      end

      # Builds an OCC symbol from components.
      #
      # @param underlying [String] the underlying symbol (1-6 chars)
      # @param date [String, Date] the expiration date
      # @param type [String] 'C' for call or 'P' for put
      # @param strike [Numeric, String] the strike price in dollars or 8-char mills string
      # @return [OCC] a new OCC instance
      # @raise [ArgumentError] if strike format is invalid
      def build(underlying:, date:, type:, strike:)
        initial = underlying.to_s.ljust(6, "\s")
        date = Date.parse(date.to_s) unless date.is_a?(Date)

        case strike
        when Numeric
          strike_mills = format('%08d', (strike * 1000).to_i)
        when /\A\d{8}\z/
          strike_mills = strike
        else
          raise ArgumentError, 'Strike must be numeric or an 8-char string!'
        end

        symbol = "#{initial}#{date.strftime('%y%m%d')}#{type}#{strike_mills}"
        new(symbol)
      end
    end

    private

    # Parses the OCC symbol string.
    # Overrides base to skip upcase (OCC symbols are already properly cased).
    #
    # @param symbol [String] the OCC symbol to parse
    # @return [MatchData, Hash] the regex match data or empty hash
    def parse(symbol)
      @full_number = symbol.to_s.strip
      @full_number.match(ID_REGEX) || {}
    end
  end
end
