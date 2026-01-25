# frozen_string_literal: true

module SecId
  # Classification of Financial Instruments (CFI) - a 6-character alphabetic code
  # that classifies financial instruments per ISO 10962.
  #
  # Format: 6 uppercase letters A-Z
  # - Position 1: Category code (14 valid values)
  # - Position 2: Group code (varies by category)
  # - Positions 3-6: Attribute codes (A-Z, with X meaning "not applicable")
  #
  # @see https://en.wikipedia.org/wiki/ISO_10962
  #
  # @example Validate a CFI code
  #   SecId::CFI.valid?('ESXXXX')  #=> true
  #   SecId::CFI.valid?('ESVUFR')  #=> true
  #
  # @example Access CFI components
  #   cfi = SecId::CFI.new('ESVUFR')
  #   cfi.category        #=> :equity
  #   cfi.group           #=> :common_shares
  #   cfi.voting?         #=> true
  class CFI < Base
    # Regular expression for parsing CFI components.
    ID_REGEX = /\A
      (?<identifier>
        (?<category_code>[A-Z])
        (?<group_code>[A-Z])
        (?<attr1>[A-Z])
        (?<attr2>[A-Z])
        (?<attr3>[A-Z])
        (?<attr4>[A-Z]))
    \z/x

    # Category codes per ISO 10962.
    CATEGORIES = {
      'E' => :equity,
      'C' => :collective_investment_vehicles,
      'D' => :debt_instruments,
      'R' => :entitlements,
      'O' => :listed_options,
      'F' => :futures,
      'S' => :swaps,
      'H' => :non_listed_options,
      'I' => :spot,
      'J' => :forwards,
      'K' => :strategies,
      'L' => :financing,
      'T' => :referential_instruments,
      'M' => :miscellaneous
    }.freeze

    # Group codes per category per ISO 10962.
    GROUPS = {
      'E' => { # Equity
        'S' => :common_shares,
        'P' => :preferred_shares,
        'C' => :convertible_common_shares,
        'F' => :convertible_preferred_shares,
        'L' => :limited_partnership_units,
        'D' => :depositary_receipts,
        'Y' => :structured_instruments,
        'M' => :miscellaneous
      },
      'C' => { # Collective Investment Vehicles
        'I' => :standard_investment_funds,
        'H' => :hedge_funds,
        'B' => :real_estate_investment_trusts,
        'E' => :exchange_traded_funds,
        'S' => :pension_funds,
        'F' => :funds_of_funds,
        'P' => :private_equity_funds,
        'M' => :miscellaneous
      },
      'D' => { # Debt Instruments
        'B' => :bonds,
        'C' => :convertible_bonds,
        'W' => :bonds_with_warrants,
        'T' => :medium_term_notes,
        'Y' => :money_market_instruments,
        'S' => :structured_instruments,
        'E' => :mortgage_backed_securities,
        'G' => :asset_backed_securities,
        'A' => :municipal_bonds,
        'N' => :municipal_notes,
        'D' => :depositary_receipts,
        'M' => :miscellaneous
      },
      'R' => { # Entitlements (Rights)
        'A' => :allotment_rights,
        'S' => :subscription_rights,
        'P' => :purchase_rights,
        'W' => :warrants,
        'F' => :mini_future_certificates,
        'D' => :depositary_receipts,
        'M' => :miscellaneous
      },
      'O' => { # Listed Options
        'C' => :call_options,
        'P' => :put_options,
        'M' => :miscellaneous
      },
      'F' => { # Futures
        'F' => :financial_futures,
        'C' => :commodities_futures,
        'M' => :miscellaneous
      },
      'S' => { # Swaps
        'R' => :rates,
        'T' => :commodities,
        'E' => :equity,
        'C' => :credit,
        'F' => :foreign_exchange,
        'M' => :miscellaneous
      },
      'H' => { # Non-Listed (Complex) Options
        'C' => :call_options,
        'P' => :put_options,
        'M' => :miscellaneous
      },
      'I' => { # Spot
        'F' => :foreign_exchange,
        'T' => :commodities,
        'M' => :miscellaneous
      },
      'J' => { # Forwards
        'F' => :foreign_exchange,
        'R' => :rates,
        'T' => :commodities,
        'E' => :equity,
        'C' => :credit,
        'M' => :miscellaneous
      },
      'K' => { # Strategies
        'R' => :rates,
        'T' => :commodities,
        'E' => :equity,
        'C' => :credit,
        'F' => :foreign_exchange,
        'Y' => :mixed,
        'M' => :miscellaneous
      },
      'L' => { # Financing
        'S' => :loan_lease,
        'R' => :repurchase_agreements,
        'P' => :securities_lending,
        'M' => :miscellaneous
      },
      'T' => { # Referential Instruments
        'I' => :currencies,
        'C' => :commodities,
        'R' => :interest_rates,
        'N' => :indices,
        'B' => :baskets,
        'D' => :stock_dividends,
        'M' => :miscellaneous
      },
      'M' => { # Miscellaneous
        'C' => :combined_instruments,
        'M' => :miscellaneous
      }
    }.freeze

    # @return [String, nil] the category code (position 1)
    attr_reader :category_code

    # @return [String, nil] the group code (position 2)
    attr_reader :group_code

    # @return [String, nil] attribute 1 (position 3)
    attr_reader :attr1

    # @return [String, nil] attribute 2 (position 4)
    attr_reader :attr2

    # @return [String, nil] attribute 3 (position 5)
    attr_reader :attr3

    # @return [String, nil] attribute 4 (position 6)
    attr_reader :attr4

    # @param cfi [String] the CFI string to parse
    def initialize(cfi)
      cfi_parts = parse(cfi)
      @identifier = cfi_parts[:identifier]
      @category_code = cfi_parts[:category_code]
      @group_code = cfi_parts[:group_code]
      @attr1 = cfi_parts[:attr1]
      @attr2 = cfi_parts[:attr2]
      @attr3 = cfi_parts[:attr3]
      @attr4 = cfi_parts[:attr4]
      @check_digit = nil
    end

    # @return [Boolean] always false - CFI has no check digit
    def has_check_digit?
      false
    end

    # Validates format including category and group codes.
    #
    # @return [Boolean]
    def valid_format?
      super && valid_category? && valid_group?
    end

    # Returns the semantic category name.
    #
    # @return [Symbol, nil] category symbol or nil if invalid
    def category
      CATEGORIES[category_code]
    end

    # Returns the semantic group name.
    #
    # @return [Symbol, nil] group symbol or nil if invalid
    def group
      GROUPS.dig(category_code, group_code)
    end

    # @return [Boolean] true if category is equity
    def equity?
      category_code == 'E'
    end

    # Voting rights (position 3 = V). Only meaningful for equity.
    #
    # @return [Boolean]
    def voting?
      equity? && attr1 == 'V'
    end

    # Non-voting (position 3 = N). Only meaningful for equity.
    #
    # @return [Boolean]
    def non_voting?
      equity? && attr1 == 'N'
    end

    # Restricted voting (position 3 = R). Only meaningful for equity.
    #
    # @return [Boolean]
    def restricted_voting?
      equity? && attr1 == 'R'
    end

    # Enhanced voting (position 3 = E). Only meaningful for equity.
    #
    # @return [Boolean]
    def enhanced_voting?
      equity? && attr1 == 'E'
    end

    # Ownership restrictions exist (position 4 = T). Only meaningful for equity.
    #
    # @return [Boolean]
    def restrictions?
      equity? && attr2 == 'T'
    end

    # No ownership restrictions (position 4 = U). Only meaningful for equity.
    #
    # @return [Boolean]
    def no_restrictions?
      equity? && attr2 == 'U'
    end

    # Fully paid shares (position 5 = F). Only meaningful for equity.
    #
    # @return [Boolean]
    def fully_paid?
      equity? && attr3 == 'F'
    end

    # Nil paid shares (position 5 = O). Only meaningful for equity.
    #
    # @return [Boolean]
    def nil_paid?
      equity? && attr3 == 'O'
    end

    # Partly paid shares (position 5 = P). Only meaningful for equity.
    #
    # @return [Boolean]
    def partly_paid?
      equity? && attr3 == 'P'
    end

    # Bearer form (position 6 = B). Only meaningful for equity.
    #
    # @return [Boolean]
    def bearer?
      equity? && attr4 == 'B'
    end

    # Registered form (position 6 = R). Only meaningful for equity.
    #
    # @return [Boolean]
    def registered?
      equity? && attr4 == 'R'
    end

    # @return [String]
    def to_s
      identifier.to_s
    end

    private

    # @return [Boolean]
    def valid_category?
      CATEGORIES.key?(category_code)
    end

    # @return [Boolean]
    def valid_group?
      GROUPS.dig(category_code, group_code) != nil
    end
  end
end
