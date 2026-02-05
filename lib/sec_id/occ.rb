# frozen_string_literal: true

require 'date'

module SecId
  # OCC Option Symbol - standardized option symbol format used by Option Clearing Corporation.
  # Format: 6-char underlying (padded) + 6-char date (YYMMDD) + type (C/P) + 8-digit strike (in mills).
  #
  # @note OCC identifiers have no check digit and validation includes both format
  #   and date parseability checks.
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
    include Normalizable

    FULL_NAME = 'OCC Option Symbol'
    ID_LENGTH = 21
    EXAMPLE = 'AAPL  210917C00150000'

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

    # @return [String, nil] the strike price in mills (thousandths of a dollar, represented as an 8-digit string)
    attr_reader :strike_mills

    class << self
      # Builds an OCC symbol from components.
      #
      # @param underlying [String] the underlying symbol (1-6 chars)
      # @param date [String, Date] the expiration date
      # @param type [String] 'C' for call or 'P' for put
      # @param strike [Numeric, String] the strike price in dollars or 8-char mills string
      # @return [OCC] a new OCC instance
      # @raise [ArgumentError] if strike format is invalid
      def build(underlying:, date:, type:, strike:)
        date_obj = date.is_a?(Date) ? date : Date.parse(date)
        strike_mills = normalize_strike_mills(strike)

        new(compose_symbol(underlying, date_obj.strftime('%y%m%d'), type, strike_mills))
      end

      # Composes an OCC symbol string from its components.
      #
      # @param underlying [String] the underlying symbol
      # @param date_str [String] the date in YYMMDD format
      # @param type [String] 'C' or 'P'
      # @param strike_mills [String, Integer] the strike in mills
      # @return [String] the composed OCC symbol
      def compose_symbol(underlying, date_str, type, strike_mills)
        padded_underlying = underlying.to_s.ljust(6, "\s")
        padded_strike = format('%08d', strike_mills.to_i)

        "#{padded_underlying}#{date_str}#{type}#{padded_strike}"
      end

      private

      # @param strike [Numeric, String] strike price or 8-char mills string
      # @return [String] 8-character strike mills string
      # @raise [ArgumentError] if strike format is invalid
      def normalize_strike_mills(strike)
        case strike
        when Numeric
          format('%08d', (strike * 1000).to_i)
        when String && /\A\d{8}\z/
          strike
        else
          raise ArgumentError, 'Strike must be numeric or an 8-char string!'
        end
      end
    end

    # @param symbol [String] the OCC symbol string to parse
    def initialize(symbol)
      symbol_parts = parse(symbol, upcase: false)
      @identifier = symbol_parts[:initial]
      @underlying = symbol_parts[:underlying]
      @date_str = symbol_parts[:date]
      @type = symbol_parts[:type]
      @strike_mills = symbol_parts[:strike_mills]
    end

    # Normalizes the OCC symbol to standard format with 6-char padded underlying and 8-digit strike.
    #
    # @return [String] the normalized OCC symbol
    # @raise [InvalidFormatError] if the OCC symbol is invalid
    def normalize!
      raise InvalidFormatError, "OCC '#{full_number}' is invalid and cannot be normalized!" unless valid?

      @full_number = self.class.compose_symbol(underlying, date_str, type, strike_mills)
    end

    # @return [Boolean]
    def valid?
      valid_format? && !date.nil? # date must be parseable
    end

    # @return [Date, nil] the parsed date or nil if invalid
    def date
      return nil unless date_str

      @date ||= Date.strptime(date_str, '%y%m%d')
    rescue ArgumentError
      nil
    end
    alias date_obj date

    # @return [Float] strike price in dollars
    def strike
      @strike ||= strike_mills.to_i / 1000.0
    end

    # @return [String]
    def to_s
      full_number
    end
    alias to_str to_s

    # @deprecated Use {#full_number} instead
    # @return [String]
    def full_symbol
      full_number
    end
  end
end
