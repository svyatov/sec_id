# frozen_string_literal: true

require_relative 'iban/country_rules'

module SecID
  # International Bank Account Number (IBAN) - an international standard for identifying
  # bank accounts across national borders (ISO 13616).
  #
  # Format: 2-letter country code + 2-digit check digits + BBAN (Basic Bank Account Number, 11-30 chars)
  # Note: Unlike other SecID identifiers, the check digits are in positions 3-4, not at the end.
  #
  # @see https://en.wikipedia.org/wiki/International_Bank_Account_Number
  # @see https://www.iban.com/structure
  #
  # @example Validate an IBAN
  #   SecID::IBAN.valid?('DE89370400440532013000')  #=> true
  #
  # @example Restore check digits
  #   SecID::IBAN.restore!('DE00370400440532013000')  #=> #<SecID::IBAN>
  class IBAN < Base
    include Checkable
    include IBANCountryRules

    FULL_NAME = 'International Bank Account Number'
    ID_LENGTH = (15..34)
    EXAMPLE = 'GB29NWBK60161331926819'
    VALID_CHARS_REGEX = /\A[A-Z0-9]+\z/

    # Regular expression for parsing IBAN components.
    # Note: Check digit positioning is handled in initialize, not in the regex.
    ID_REGEX = /\A
      (?<country_code>[A-Z]{2})
      (?<rest>[A-Z0-9]{13,32})
    \z/x

    # Returns sorted array of all supported country codes.
    #
    # @return [Array<String>]
    def self.supported_countries
      @supported_countries ||= (COUNTRY_RULES.keys + LENGTH_ONLY_COUNTRIES.keys).sort.freeze
    end

    # @return [String, nil] the ISO 3166-1 alpha-2 country code
    attr_reader :country_code

    # @return [String, nil] the Basic Bank Account Number (country-specific format)
    attr_reader :bban

    # @return [String, nil] the bank code (extracted from BBAN if country rules define it)
    attr_reader :bank_code

    # @return [String, nil] the branch code (extracted from BBAN if country rules define it)
    attr_reader :branch_code

    # @return [String, nil] the account number (extracted from BBAN if country rules define it)
    attr_reader :account_number

    # @return [String, nil] the national check digit (extracted from BBAN if country rules define it)
    attr_reader :national_check

    # @param iban [String] the IBAN string to parse
    def initialize(iban)
      iban_parts = parse(iban)
      @country_code = iban_parts[:country_code]
      rest = iban_parts[:rest]

      if @country_code && rest
        extract_check_digit_and_bban(rest)
        @identifier = "#{@country_code}#{@bban}" if @bban
      end

      extract_bban_components if valid_format?
    end

    # @return [String]
    # @raise [InvalidFormatError] if the IBAN format is invalid
    def restore
      cd = calculate_check_digit
      "#{country_code}#{cd.to_s.rjust(2, '0')}#{bban}"
    end

    # @return [Integer] the calculated 2-digit check value (1-98)
    # @raise [InvalidFormatError] if the IBAN format is invalid
    def calculate_check_digit
      validate_format_for_calculation!
      mod97(numeric_string_for_check)
    end

    # @return [Boolean]
    def valid_bban_format?
      return false unless bban

      rule = country_rule
      return valid_bban_length_only? unless rule

      bban.length == rule[:length] && bban.match?(rule[:format])
    end

    # @return [Hash, nil] the validation rule or nil if country is unknown
    def country_rule
      COUNTRY_RULES[country_code]
    end

    # @return [Boolean]
    def known_country?
      COUNTRY_RULES.key?(country_code) || LENGTH_ONLY_COUNTRIES.key?(country_code)
    end

    # @return [String]
    def to_s
      return full_id unless check_digit

      "#{country_code}#{check_digit.to_s.rjust(2, '0')}#{bban}"
    end

    # @return [String, nil]
    def to_pretty_s
      to_s.scan(/.{1,4}/).join(' ') if valid?
    end

    private

    # @return [Hash]
    def components
      hash = { country_code:, bban:, check_digit: }
      hash[:bank_code] = bank_code if bank_code
      hash[:branch_code] = branch_code if branch_code
      hash[:account_number] = account_number if account_number
      hash[:national_check] = national_check if national_check
      hash
    end

    # @return [Integer]
    def check_digit_width
      2
    end

    # @return [Boolean]
    def valid_format?
      return false unless identifier

      valid_bban_format?
    end

    # @return [Array<Symbol>]
    def detect_errors
      return [:invalid_bban] if identifier && !valid_bban_format?

      super
    end

    # @param code [Symbol]
    # @return [String]
    def validation_message(code)
      return "BBAN format is invalid for country '#{country_code}'" if code == :invalid_bban

      super
    end

    # @param rest [String] the IBAN string after country code
    # @return [void]
    def extract_check_digit_and_bban(rest)
      expected = expected_bban_length_for_country

      if check_digits?(rest, expected)
        @check_digit = rest[0, 2].to_i
        @bban = rest[2..]
      else
        @check_digit = nil
        @bban = rest
      end
    end

    # @return [Integer, nil] the expected BBAN length or nil if unknown
    def expected_bban_length_for_country
      COUNTRY_RULES.dig(country_code, :length) || LENGTH_ONLY_COUNTRIES[country_code]
    end

    # @param rest [String] the IBAN string after country code
    # @param expected_bban_length [Integer, nil] the expected BBAN length for the country
    # @return [Boolean]
    def check_digits?(rest, expected_bban_length)
      return false unless rest[0, 2].match?(/\A\d{2}\z/)
      return true unless expected_bban_length

      # If we know expected BBAN length, check if rest matches with or without check digits
      rest.length == expected_bban_length + 2 || rest.length != expected_bban_length
    end

    # @return [void]
    def extract_bban_components
      rule = country_rule
      return unless rule&.key?(:components)

      rule[:components].each do |name, (start, length)|
        instance_variable_set(:"@#{name}", bban[start, length])
      end
    end

    # @return [Boolean]
    def valid_bban_length_only?
      expected_length = LENGTH_ONLY_COUNTRIES[country_code]
      return true unless expected_length

      bban.length == expected_length
    end

    # @return [String] the numeric string representation
    def numeric_string_for_check
      "#{bban}#{country_code}00".each_char.map { |char| CHAR_TO_DIGIT.fetch(char) }.join
    end
  end
end
