# frozen_string_literal: true

require_relative 'iban/country_rules'

module SecId
  # https://en.wikipedia.org/wiki/International_Bank_Account_Number
  class IBAN < Base
    include IBANCountryRules

    # IBAN format: 2-letter country code + 2-digit check digits + BBAN (11-30 chars)
    # Note: Check digits are in positions 3-4, unlike other SecId identifiers where check digit is at the end
    # The regex captures the full IBAN without check digit positioning logic - we handle that in initialize
    ID_REGEX = /\A
      (?<country_code>[A-Z]{2})
      (?<rest>[A-Z0-9]{13,32})
    \z/x

    attr_reader :country_code, :bban, :bank_code, :branch_code, :account_number, :national_check

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

    def calculate_check_digit
      unless valid_format?
        raise InvalidFormatError, "IBAN '#{full_number}' is invalid and check-digit cannot be calculated!"
      end

      mod97(numeric_string_for_check)
    end

    def valid_format?
      return false unless identifier

      valid_bban_format?
    end

    def valid_bban_format?
      return false unless bban

      rule = country_rule
      return valid_bban_length_only? unless rule

      bban.length == rule[:length] && bban.match?(rule[:format])
    end

    def country_rule
      COUNTRY_RULES[country_code]
    end

    def known_country?
      COUNTRY_RULES.key?(country_code) || LENGTH_ONLY_COUNTRIES.key?(country_code)
    end

    def to_s
      return full_number unless check_digit

      "#{country_code}#{check_digit.to_s.rjust(2, '0')}#{bban}"
    end

    private

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

    def check_digits?(rest, expected_bban_length)
      return false unless rest[0, 2].match?(/\A\d{2}\z/)
      return true unless expected_bban_length

      # If we know expected BBAN length, check if rest matches with or without check digits
      rest.length == expected_bban_length + 2 || rest.length != expected_bban_length
    end

    def expected_bban_length_for_country
      COUNTRY_RULES.dig(country_code, :length) || LENGTH_ONLY_COUNTRIES[country_code]
    end

    def valid_bban_length_only?
      expected_length = LENGTH_ONLY_COUNTRIES[country_code]
      return true unless expected_length

      bban.length == expected_length
    end

    def extract_bban_components
      rule = country_rule
      return unless rule&.key?(:components)

      rule[:components].each do |name, (start, length)|
        instance_variable_set(:"@#{name}", bban[start, length])
      end
    end

    # For MOD-97 check: BBAN + country_code + "00" -> convert letters to digits
    def numeric_string_for_check
      "#{bban}#{country_code}00".each_char.map { |char| char_to_digit(char) }.join
    end
  end
end
