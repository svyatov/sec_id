# frozen_string_literal: true

module SecId
  # Valoren (Swiss Security Number) - a numeric identifier for securities
  # in Switzerland, Liechtenstein, and Belgium.
  #
  # Format: 5-9 numeric digits
  #
  # @note Valoren identifiers have no check digit. The {#has_check_digit?} method
  #   returns false and validation is based solely on format.
  #
  # @see https://en.wikipedia.org/wiki/Valoren_number
  #
  # @example Validate a Valoren
  #   SecId::Valoren.valid?('3886335')    #=> true
  #   SecId::Valoren.valid?('003886335')  #=> true
  #
  # @example Normalize a Valoren to 9 digits
  #   SecId::Valoren.normalize!('3886335')  #=> '003886335'
  class Valoren < Base
    include Normalizable

    # Regular expression for parsing Valoren components.
    ID_REGEX = /\A
      (?=\d{5,9}\z)(?<padding>0*)(?<identifier>[1-9]\d{4,8})
    \z/x

    # @return [String, nil] the leading zeros in the Valoren
    attr_reader :padding

    # @param valoren [String, Integer] the Valoren to parse
    def initialize(valoren)
      valoren_parts = parse(valoren)
      @padding = valoren_parts[:padding]
      @identifier = valoren_parts[:identifier]
      @check_digit = nil
    end

    # Valid country codes for Valoren to ISIN conversion.
    ISIN_COUNTRY_CODES = Set.new(%w[CH LI]).freeze

    # @param country_code [String] the ISO 3166-1 alpha-2 country code (default: 'CH')
    # @return [ISIN] a new ISIN instance with calculated check digit
    # @raise [InvalidFormatError] if the country code is not CH or LI
    def to_isin(country_code = 'CH')
      unless ISIN_COUNTRY_CODES.include?(country_code)
        raise InvalidFormatError, "'#{country_code}' is not a valid Valoren country code!"
      end

      normalize!
      isin = ISIN.new(country_code + full_number)
      isin.restore!
      isin
    end

    # @return [Boolean] always false
    def has_check_digit?
      false
    end

    # Normalizes the Valoren to a 9-digit zero-padded format.
    # Updates both @full_number and @padding to reflect the normalized state.
    #
    # @return [String] the normalized 9-digit Valoren
    # @raise [InvalidFormatError] if the Valoren format is invalid
    def normalize!
      raise InvalidFormatError, "Valoren '#{full_number}' is invalid and cannot be normalized!" unless valid_format?

      @full_number = @identifier.rjust(9, '0')
      @padding = @full_number[0, 9 - @identifier.length]
      @full_number
    end

    # @return [String]
    def to_s
      full_number
    end
    alias to_str to_s
  end
end
