# frozen_string_literal: true

module SecID
  # Country-specific BBAN validation rules for IBAN.
  #
  # @api private
  # rubocop:disable Metrics/ModuleLength
  module IBANCountryRules
    # Country-specific BBAN rules for EU/EEA countries
    # Each entry defines:
    #   - :length => total BBAN length
    #   - :format => regex pattern for BBAN structure validation
    #   - :components => hash mapping component names to [start, length] positions
    #
    # Sources:
    # - https://en.wikipedia.org/wiki/International_Bank_Account_Number
    # - https://www.swift.com/standards/data-standards/iban-international-bank-account-number
    COUNTRY_RULES = {
      # Austria - 16 chars: 5-digit bank code + 11-digit account
      'AT' => {
        length: 16,
        format: /\A\d{16}\z/,
        components: { bank_code: [0, 5], account_number: [5, 11] }
      },
      # Belgium - 12 chars: 3-digit bank code + 7-digit account + 2-digit national check
      'BE' => {
        length: 12,
        format: /\A\d{12}\z/,
        components: { bank_code: [0, 3], account_number: [3, 7], national_check: [10, 2] }
      },
      # Bulgaria - 18 chars: 4-letter bank code + 4-digit branch + 2-digit account type + 8-digit account
      'BG' => {
        length: 18,
        format: /\A[A-Z]{4}\d{14}\z/,
        components: { bank_code: [0, 4], branch_code: [4, 4], account_number: [10, 8] }
      },
      # Croatia - 17 chars: 7-digit bank code + 10-digit account
      'HR' => {
        length: 17,
        format: /\A\d{17}\z/,
        components: { bank_code: [0, 7], account_number: [7, 10] }
      },
      # Cyprus - 24 chars: 3-digit bank code + 5-digit branch + 16-char account
      'CY' => {
        length: 24,
        format: /\A\d{8}[A-Z0-9]{16}\z/,
        components: { bank_code: [0, 3], branch_code: [3, 5], account_number: [8, 16] }
      },
      # Czech Republic - 20 chars: 4-digit bank code + 16-digit account
      'CZ' => {
        length: 20,
        format: /\A\d{20}\z/,
        components: { bank_code: [0, 4], account_number: [4, 16] }
      },
      # Denmark - 14 chars: 4-digit bank code + 10-digit account
      'DK' => {
        length: 14,
        format: /\A\d{14}\z/,
        components: { bank_code: [0, 4], account_number: [4, 10] }
      },
      # Estonia - 16 chars: 2-digit bank code + 14-digit account
      'EE' => {
        length: 16,
        format: /\A\d{16}\z/,
        components: { bank_code: [0, 2], account_number: [2, 14] }
      },
      # Finland - 14 chars: 3-digit bank code + 11-digit account
      'FI' => {
        length: 14,
        format: /\A\d{14}\z/,
        components: { bank_code: [0, 3], account_number: [3, 11] }
      },
      # France - 23 chars: 5-digit bank + 5-digit branch + 11-char account + 2-digit national check
      'FR' => {
        length: 23,
        format: /\A\d{10}[A-Z0-9]{11}\d{2}\z/,
        components: { bank_code: [0, 5], branch_code: [5, 5], account_number: [10, 11], national_check: [21, 2] }
      },
      # Germany - 18 chars: 8-digit bank code (Bankleitzahl) + 10-digit account
      'DE' => {
        length: 18,
        format: /\A\d{18}\z/,
        components: { bank_code: [0, 8], account_number: [8, 10] }
      },
      # Greece - 23 chars: 3-digit bank code + 4-digit branch + 16-digit account
      'GR' => {
        length: 23,
        format: /\A\d{23}\z/,
        components: { bank_code: [0, 3], branch_code: [3, 4], account_number: [7, 16] }
      },
      # Hungary - 24 chars: 3-digit bank code + 4-digit branch + 16-digit account + 1-digit national check
      'HU' => {
        length: 24,
        format: /\A\d{24}\z/,
        components: { bank_code: [0, 3], branch_code: [3, 4], account_number: [7, 16], national_check: [23, 1] }
      },
      # Iceland - 22 chars: 4-digit bank code + 2-digit branch + 6-digit account + 10-digit holder ID
      'IS' => {
        length: 22,
        format: /\A\d{22}\z/,
        components: { bank_code: [0, 4], branch_code: [4, 2], account_number: [6, 6] }
      },
      # Ireland - 18 chars: 4-letter bank code + 6-digit branch + 8-digit account
      'IE' => {
        length: 18,
        format: /\A[A-Z]{4}\d{14}\z/,
        components: { bank_code: [0, 4], branch_code: [4, 6], account_number: [10, 8] }
      },
      # Italy - 23 chars: 1-letter check + 5-digit bank code + 5-digit branch + 12-char account
      'IT' => {
        length: 23,
        format: /\A[A-Z]\d{10}[A-Z0-9]{12}\z/,
        components: { national_check: [0, 1], bank_code: [1, 5], branch_code: [6, 5], account_number: [11, 12] }
      },
      # Latvia - 17 chars: 4-letter bank code + 13-digit account
      'LV' => {
        length: 17,
        format: /\A[A-Z]{4}[A-Z0-9]{13}\z/,
        components: { bank_code: [0, 4], account_number: [4, 13] }
      },
      # Liechtenstein - 17 chars: 5-digit bank code + 12-char account
      'LI' => {
        length: 17,
        format: /\A\d{5}[A-Z0-9]{12}\z/,
        components: { bank_code: [0, 5], account_number: [5, 12] }
      },
      # Lithuania - 16 chars: 5-digit bank code + 11-digit account
      'LT' => {
        length: 16,
        format: /\A\d{16}\z/,
        components: { bank_code: [0, 5], account_number: [5, 11] }
      },
      # Luxembourg - 16 chars: 3-digit bank code + 13-char account
      'LU' => {
        length: 16,
        format: /\A\d{3}[A-Z0-9]{13}\z/,
        components: { bank_code: [0, 3], account_number: [3, 13] }
      },
      # Malta - 27 chars: 4-letter bank code + 5-digit branch + 18-char account
      'MT' => {
        length: 27,
        format: /\A[A-Z]{4}\d{5}[A-Z0-9]{18}\z/,
        components: { bank_code: [0, 4], branch_code: [4, 5], account_number: [9, 18] }
      },
      # Monaco - 23 chars: same format as France
      'MC' => {
        length: 23,
        format: /\A\d{10}[A-Z0-9]{11}\d{2}\z/,
        components: { bank_code: [0, 5], branch_code: [5, 5], account_number: [10, 11], national_check: [21, 2] }
      },
      # Netherlands - 14 chars: 4-letter bank code + 10-digit account
      'NL' => {
        length: 14,
        format: /\A[A-Z]{4}\d{10}\z/,
        components: { bank_code: [0, 4], account_number: [4, 10] }
      },
      # Norway - 11 chars: 4-digit bank code + 6-digit account + 1-digit national check
      'NO' => {
        length: 11,
        format: /\A\d{11}\z/,
        components: { bank_code: [0, 4], account_number: [4, 6], national_check: [10, 1] }
      },
      # Poland - 24 chars: 3-digit bank code + 4-digit branch + 1-digit check + 16-digit account
      'PL' => {
        length: 24,
        format: /\A\d{24}\z/,
        components: { bank_code: [0, 3], branch_code: [3, 4], national_check: [7, 1], account_number: [8, 16] }
      },
      # Portugal - 21 chars: 4-digit bank code + 4-digit branch + 11-digit account + 2-digit national check
      'PT' => {
        length: 21,
        format: /\A\d{21}\z/,
        components: { bank_code: [0, 4], branch_code: [4, 4], account_number: [8, 11], national_check: [19, 2] }
      },
      # Romania - 20 chars: 4-letter bank code + 16-char account
      'RO' => {
        length: 20,
        format: /\A[A-Z]{4}[A-Z0-9]{16}\z/,
        components: { bank_code: [0, 4], account_number: [4, 16] }
      },
      # San Marino - 23 chars: same format as Italy
      'SM' => {
        length: 23,
        format: /\A[A-Z]\d{10}[A-Z0-9]{12}\z/,
        components: { national_check: [0, 1], bank_code: [1, 5], branch_code: [6, 5], account_number: [11, 12] }
      },
      # Slovakia - 20 chars: 4-digit bank code + 16-digit account
      'SK' => {
        length: 20,
        format: /\A\d{20}\z/,
        components: { bank_code: [0, 4], account_number: [4, 16] }
      },
      # Slovenia - 15 chars: 5-digit bank code + 8-digit account + 2-digit national check
      'SI' => {
        length: 15,
        format: /\A\d{15}\z/,
        components: { bank_code: [0, 5], account_number: [5, 8], national_check: [13, 2] }
      },
      # Spain - 20 chars: 4-digit bank code + 4-digit branch + 2-digit national check + 10-digit account
      'ES' => {
        length: 20,
        format: /\A\d{20}\z/,
        components: { bank_code: [0, 4], branch_code: [4, 4], national_check: [8, 2], account_number: [10, 10] }
      },
      # Sweden - 20 chars: 3-digit bank code + 17-digit account
      'SE' => {
        length: 20,
        format: /\A\d{20}\z/,
        components: { bank_code: [0, 3], account_number: [3, 17] }
      },
      # Switzerland - 17 chars: 5-digit bank code + 12-char account
      'CH' => {
        length: 17,
        format: /\A\d{5}[A-Z0-9]{12}\z/,
        components: { bank_code: [0, 5], account_number: [5, 12] }
      },
      # United Kingdom - 18 chars: 4-letter bank code + 6-digit branch (sort code) + 8-digit account
      'GB' => {
        length: 18,
        format: /\A[A-Z]{4}\d{14}\z/,
        components: { bank_code: [0, 4], branch_code: [4, 6], account_number: [10, 8] }
      }
    }.freeze

    # Countries where only length validation is performed (non-EU/EEA countries)
    # Format: country_code => expected BBAN length
    LENGTH_ONLY_COUNTRIES = {
      'AD' => 20, # Andorra
      'AE' => 19, # UAE
      'AL' => 24, # Albania
      'AZ' => 24, # Azerbaijan
      'BA' => 16, # Bosnia and Herzegovina
      'BY' => 24, # Belarus
      'DO' => 24, # Dominican Republic
      'EG' => 25, # Egypt
      'GE' => 18, # Georgia
      'GI' => 19, # Gibraltar
      'GT' => 24, # Guatemala
      'IL' => 19, # Israel
      'IQ' => 19, # Iraq
      'JO' => 26, # Jordan
      'KW' => 26, # Kuwait
      'KZ' => 16, # Kazakhstan
      'LB' => 24, # Lebanon
      'LC' => 28, # Saint Lucia
      'MD' => 20, # Moldova
      'ME' => 18, # Montenegro
      'MK' => 15, # North Macedonia
      'MR' => 23, # Mauritania
      'MU' => 26, # Mauritius
      'PS' => 25, # Palestine
      'QA' => 25, # Qatar
      'RS' => 18, # Serbia
      'SA' => 20, # Saudi Arabia
      'SC' => 27, # Seychelles
      'ST' => 21, # Sao Tome and Principe
      'SV' => 24, # El Salvador
      'TL' => 19, # Timor-Leste
      'TN' => 20, # Tunisia
      'TR' => 22, # Turkey
      'UA' => 25, # Ukraine
      'VA' => 18, # Vatican City
      'VG' => 20, # British Virgin Islands
      'XK' => 16  # Kosovo
    }.freeze
  end
  # rubocop:enable Metrics/ModuleLength
end
