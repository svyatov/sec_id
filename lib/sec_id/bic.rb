# frozen_string_literal: true

require_relative 'bic/country_codes'

module SecID
  # Business Identifier Code (BIC / SWIFT code) - an international standard for
  # identifying financial and non-financial institutions (ISO 9362).
  #
  # Format: 4-letter institution code + 2-letter country code + 2-alphanumeric
  # location code, optionally followed by a 3-alphanumeric branch code (BIC8 or BIC11).
  #
  # Validation confirms the structure and that the embedded country code is a real
  # ISO 3166-1 / SWIFT-recognized country. It does *not* verify that the institution,
  # location, or branch corresponds to a registered SWIFT participant — that requires
  # the licensed SWIFT registry.
  #
  # @see https://en.wikipedia.org/wiki/ISO_9362
  #
  # @example Validate a BIC
  #   SecID::BIC.valid?('DEUTDEFF')     #=> true (BIC8)
  #   SecID::BIC.valid?('DEUTDEFF500')  #=> true (BIC11)
  #
  # @example Access BIC components
  #   bic = SecID::BIC.new('DEUTDEFF500')
  #   bic.bank_code      #=> "DEUT"
  #   bic.country_code   #=> "DE"
  #   bic.location_code  #=> "FF"
  #   bic.branch_code    #=> "500"
  class BIC < Base
    FULL_NAME = 'Business Identifier Code'
    ID_LENGTH = [8, 11].freeze
    EXAMPLE = 'DEUTDEFF500'
    VALID_CHARS_REGEX = /\A[A-Z0-9]+\z/

    # Regular expression for parsing BIC components.
    # The optional all-or-nothing branch code makes the length exactly 8 or 11.
    ID_REGEX = /\A
      (?<bank_code>[A-Z]{4})
      (?<country_code>[A-Z]{2})
      (?<location_code>[A-Z0-9]{2})
      (?<branch_code>[A-Z0-9]{3})?
    \z/x

    # Returns the sorted array of all recognized country codes.
    #
    # @return [Array<String>]
    def self.countries
      @countries ||= COUNTRY_CODES.to_a.sort.freeze
    end

    # @return [String, nil] the 4-letter institution (bank) code
    attr_reader :bank_code

    # @return [String, nil] the 2-letter ISO 3166-1 country code
    attr_reader :country_code

    # @return [String, nil] the 2-alphanumeric location code
    attr_reader :location_code

    # @return [String, nil] the 3-alphanumeric branch code, or nil for a BIC8
    attr_reader :branch_code

    # @param bic [String] the BIC string to parse
    def initialize(bic)
      bic_parts = parse(bic)
      @bank_code = bic_parts[:bank_code]
      @country_code = bic_parts[:country_code]
      @location_code = bic_parts[:location_code]
      @branch_code = bic_parts[:branch_code]
      @identifier = "#{@bank_code}#{@country_code}#{@location_code}#{@branch_code}" if @bank_code
    end

    # Generates a random BIC: 4 letters + a recognized country + 2 alphanumerics,
    # with a 3-alphanumeric branch present about half the time (BIC8 or BIC11).
    #
    # @param random [Random] source of randomness
    # @return [String] a valid 8- or 11-character BIC
    def self.generate_body(random)
      bank = random_string(ALPHA, 4, random: random)
      country = countries.sample(random: random)
      location = random_string(ALPHANUMERIC, 2, random: random)
      branch = random.rand(2).zero? ? '' : random_string(ALPHANUMERIC, 3, random: random)
      "#{bank}#{country}#{location}#{branch}"
    end
    private_class_method :generate_body

    private

    # @return [Hash]
    def components = { bank_code:, country_code:, location_code:, branch_code: }

    # @return [Boolean]
    def valid_format?
      return false unless identifier

      recognized_country?
    end

    # @return [Array<Symbol>]
    def detect_errors
      return [:invalid_country] if identifier && !recognized_country?

      super
    end

    # @param code [Symbol]
    # @return [String]
    def validation_message(code)
      return "Country code '#{country_code}' is not a recognized ISO 3166 / SWIFT country" if code == :invalid_country

      super
    end

    # @return [Boolean]
    def recognized_country?
      COUNTRY_CODES.include?(country_code)
    end
  end
end
