# frozen_string_literal: true

require_relative 'cfi/tables'

module SecID
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
  #   SecID::CFI.valid?('ESXXXX')  #=> true
  #   SecID::CFI.valid?('ESVUFR')  #=> true
  #
  # @example Access CFI components
  #   cfi = SecID::CFI.new('ESVUFR')
  #   cfi.category        #=> :equity
  #   cfi.group           #=> :common_shares
  #   cfi.voting?         #=> true
  class CFI < Base
    FULL_NAME = 'Classification of Financial Instruments'
    ID_LENGTH = 6
    EXAMPLE = 'ESVUFR'
    VALID_CHARS_REGEX = /\A[A-Z]+\z/

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

    # Category codes per ISO 10962:2021, derived from {SecID::CFITables}
    # (letter => symbol).
    CATEGORIES = CFITables::CATEGORIES.transform_values(&:first).freeze

    # Group codes per category per ISO 10962:2021, derived from
    # {SecID::CFITables} (letter => { letter => symbol }).
    GROUPS = CFITables::GROUPS.transform_values do |groups|
      groups.transform_values { |group| group[:symbol] }.freeze
    end.freeze

    # Returns the category codes hash.
    #
    # @return [Hash{String => Symbol}]
    def self.categories
      CATEGORIES
    end

    # Returns the groups hash for a given category code.
    #
    # @param category_code [String] single-letter category code
    # @return [Hash{String => Symbol}, nil]
    def self.groups_for(category_code)
      GROUPS[category_code.to_s.upcase]
    end

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

    # Generates a random CFI: a category, a valid group for it, and 4 attribute letters.
    #
    # @param random [Random] source of randomness
    # @return [String] a 6-character CFI code
    def self.generate_body(random)
      category = CATEGORIES.keys.sample(random: random)
      group = GROUPS[category].keys.sample(random: random)
      "#{category}#{group}#{random_string(ALPHA, 4, random: random)}"
    end
    private_class_method :generate_body

    private

    # @return [Hash]
    def components = { category_code:, group_code:, attr1:, attr2:, attr3:, attr4: }

    # @return [Boolean]
    def valid_format?
      super && valid_category? && valid_group?
    end

    # @return [Array<Symbol>]
    def detect_errors
      return super unless identifier

      errors = []
      errors << :invalid_category unless valid_category?
      errors << :invalid_group unless valid_group?
      errors
    end

    # @param code [Symbol]
    # @return [String]
    def validation_message(code)
      case code
      when :invalid_category
        "Category '#{category_code}' is not a valid CFI category"
      when :invalid_group
        "Group '#{group_code}' is not valid for category '#{category_code}'"
      else
        super
      end
    end

    # @return [Boolean]
    def valid_category?
      CATEGORIES.key?(category_code)
    end

    # @return [Boolean]
    def valid_group?
      !GROUPS.dig(category_code, group_code).nil?
    end
  end
end
