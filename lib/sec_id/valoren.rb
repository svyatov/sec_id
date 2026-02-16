# frozen_string_literal: true

module SecId
  # Valoren (Swiss Security Number) - a numeric identifier for securities
  # in Switzerland, Liechtenstein, and Belgium.
  #
  # Format: 5-9 numeric digits
  #
  # @note Valoren identifiers have no check digit and validation is based solely on format.
  #
  # @see https://en.wikipedia.org/wiki/Valoren_number
  #
  # @example Validate a Valoren
  #   SecId::Valoren.valid?('3886335')    #=> true
  #   SecId::Valoren.valid?('003886335')  #=> true
  #
  # @example Normalize a Valoren to 9 digits
  #   SecId::Valoren.normalize('3886335')  #=> '003886335'
  class Valoren < Base
    FULL_NAME = 'Valoren Number'
    ID_LENGTH = (5..9)
    EXAMPLE = '3886335'
    VALID_CHARS_REGEX = /\A[0-9]+\z/

    # Regular expression for parsing Valoren components.
    ID_REGEX = /\A
      (?=\d{5,9}\z)(?<padding>0*)(?<identifier>[1-9]\d{4,8})
    \z/x

    # Valid country codes for Valoren to ISIN conversion.
    ISIN_COUNTRY_CODES = Set.new(%w[CH LI]).freeze

    # @return [String, nil] the leading zeros in the Valoren
    attr_reader :padding

    # @param valoren [String, Integer] the Valoren to parse
    def initialize(valoren)
      valoren_parts = parse(valoren)
      @padding = valoren_parts[:padding]
      @identifier = valoren_parts[:identifier]
    end

    # @param country_code [String] the ISO 3166-1 alpha-2 country code (default: 'CH')
    # @return [ISIN] a new ISIN instance with calculated check digit
    # @raise [InvalidFormatError] if the country code is not CH or LI
    def to_isin(country_code = 'CH')
      unless ISIN_COUNTRY_CODES.include?(country_code)
        raise InvalidFormatError, "'#{country_code}' is not a valid Valoren country code!"
      end

      normalize!
      isin = ISIN.new(country_code + full_id)
      isin.restore!
      isin
    end

    # @return [String] the normalized 9-digit Valoren
    # @raise [InvalidFormatError]
    def normalized
      validate!
      @identifier.rjust(self.class::ID_LENGTH.max, '0')
    end

    # @return [self]
    # @raise [InvalidFormatError]
    def normalize!
      super
      @padding = @full_id[0, self.class::ID_LENGTH.max - @identifier.length]
      self
    end

    # @return [String]
    def to_s
      full_id
    end
  end
end
