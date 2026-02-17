# frozen_string_literal: true

module SecID
  # International Securities Identification Number (ISIN) - a 12-character alphanumeric code
  # that uniquely identifies a security globally.
  #
  # Format: 2-letter country code + 9-character NSIN + 1-digit check digit
  #
  # @see https://en.wikipedia.org/wiki/International_Securities_Identification_Number
  #
  # @example Validate an ISIN
  #   SecID::ISIN.valid?('US5949181045')  #=> true
  #
  # @example Restore check digit
  #   SecID::ISIN.restore!('US594918104')  #=> #<SecID::ISIN>
  class ISIN < Base
    include Checkable

    FULL_NAME = 'International Securities Identification Number'
    ID_LENGTH = 12
    EXAMPLE = 'US5949181045'
    VALID_CHARS_REGEX = /\A[A-Z0-9]+\z/

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
        US CA AG AI AN AR AS AW BB BL BM BO BQ BS BZ CL CO CR CW DM DO EC FM GD
        GS GU GY HN HT JM KN KY LC MF MH MP MX NI PA PE PH PR PW PY SR SV SX TT
        UM UY VC VE VG VI YT
      ]
    ).freeze

    # Maps country codes to their NSIN identifier types.
    # Countries not in this map return :generic (CGS countries handled via {#cgs?}).
    NSIN_COUNTRY_TYPES = {
      # SEDOL countries (UK, Ireland, Crown Dependencies, and Overseas Territories)
      'GB' => :sedol,
      'IE' => :sedol,
      'GG' => :sedol,
      'IM' => :sedol,
      'JE' => :sedol,
      'FK' => :sedol,
      # WKN country (Germany)
      'DE' => :wkn,
      # Valoren countries (Switzerland and Liechtenstein)
      'CH' => :valoren,
      'LI' => :valoren
    }.freeze

    # Country codes that use SEDOL as their national identifier.
    SEDOL_COUNTRY_CODES = Set.new(%w[GB IE IM JE GG FK]).freeze

    # Country codes that use Valoren as their national identifier.
    VALOREN_COUNTRY_CODES = Set.new(%w[CH LI]).freeze

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
      mod10(luhn_sum_standard(reversed_digits_multi(identifier)))
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

    # @return [Boolean] true if the country code uses SEDOL
    def sedol?
      SEDOL_COUNTRY_CODES.include?(country_code)
    end

    # @return [Boolean] true if the country code uses WKN
    def wkn?
      country_code == 'DE'
    end

    # @return [Boolean] true if the country code uses Valoren
    def valoren?
      VALOREN_COUNTRY_CODES.include?(country_code)
    end

    # @return [SEDOL] a new SEDOL instance
    # @raise [InvalidFormatError] if the country code is not valid for SEDOL
    def to_sedol
      raise InvalidFormatError, "'#{country_code}' is not a SEDOL country code!" unless sedol?

      SEDOL.new(nsin[2..])
    end

    # @return [WKN] a new WKN instance
    # @raise [InvalidFormatError] if the country code is not DE
    def to_wkn
      raise InvalidFormatError, "'#{country_code}' is not a WKN country code!" unless wkn?

      WKN.new(nsin[3..])
    end

    # @return [Valoren] a new Valoren instance
    # @raise [InvalidFormatError] if the country code is not CH or LI
    def to_valoren
      raise InvalidFormatError, "'#{country_code}' is not a Valoren country code!" unless valoren?

      Valoren.new(nsin)
    end

    # Returns the type of NSIN embedded in this ISIN.
    #
    # @return [Symbol] :cusip, :sedol, :wkn, :valoren, or :generic
    def nsin_type
      return :cusip if cgs?

      NSIN_COUNTRY_TYPES.fetch(country_code, :generic)
    end

    # Extracts the national identifier from this ISIN.
    #
    # @return [CUSIP, SEDOL, WKN, Valoren, String] the extracted identifier
    # @raise [InvalidFormatError] if ISIN format is invalid
    def to_nsin
      raise InvalidFormatError, 'Invalid ISIN format' unless valid_format?

      case nsin_type
      when :cusip   then to_cusip
      when :sedol   then SEDOL.new(nsin[2..])
      when :wkn     then WKN.new(nsin[3..])
      when :valoren then Valoren.new(nsin)
      else nsin # :generic - return raw string
      end
    end
  end
end
