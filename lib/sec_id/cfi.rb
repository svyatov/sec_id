# frozen_string_literal: true

require_relative 'cfi/tables'

module SecID
  # Classification of Financial Instruments (CFI) - a 6-character alphabetic code
  # that classifies financial instruments per ISO 10962:2021.
  #
  # Format: 6 uppercase letters A-Z
  # - Position 1: Category code (14 valid values)
  # - Position 2: Group code (varies by category)
  # - Positions 3-6: Attribute codes, strictly validated per group (X = "not applicable")
  #
  # @see https://en.wikipedia.org/wiki/ISO_10962
  #
  # @example Validate a CFI code
  #   SecID::CFI.valid?('ESVUFR')  #=> true
  #   SecID::CFI.valid?('ESZZZZ')  #=> false (Z is not a permissible equity attribute)
  #
  # @example Access CFI components and decode the classification
  #   cfi = SecID::CFI.new('ESVUFR')
  #   cfi.category                                #=> :equity
  #   cfi.group                                   #=> :common_shares
  #   cfi.decode.category.equity?                 #=> true
  #   cfi.decode.attributes.voting_right.voting?  #=> true
  #   cfi.decode.to_s                             #=> "Equities / Common/Ordinary shares: Voting, ..."
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

    # Category codes per ISO 10962:2021, derived from {SecID::CFI::Tables}
    # (letter => symbol).
    CATEGORIES = DeepFreeze.call(Tables::CATEGORIES.transform_values(&:first))

    # Group codes per category per ISO 10962:2021, derived from
    # {SecID::CFI::Tables} (letter => { letter => symbol }).
    GROUPS = DeepFreeze.call(
      Tables::GROUPS.transform_values { |groups| groups.transform_values { |group| group[:symbol] } }
    )

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

    # Decodes this CFI into its full ISO 10962:2021 classification.
    #
    # @return [Classification, nil] the classification, or nil if this CFI is invalid
    def decode
      return nil unless valid?

      Classification.new(category_code, group_code, attribute_letters)
    end

    # @return [String]
    def to_s
      identifier.to_s
    end

    # Generates a random CFI: a category, a valid group, and per-position
    # attribute letters sampled only from the letters the tables permit (each
    # position also allows X; pure-N/A positions allow only X). The ED
    # cross-position rule is honored so every generated code is valid.
    #
    # @param random [Random] source of randomness
    # @return [String] a 6-character CFI code
    def self.generate_body(random)
      category_code = Tables::CATEGORIES.keys.sample(random: random)
      group_code = Tables::GROUPS[category_code].keys.sample(random: random)
      attributes = Tables::GROUPS[category_code][group_code][:attributes]
      letters = attributes.map { |position| sample_attribute(position, random) }
      enforce_ed_rule(category_code, group_code, letters, random)
      "#{category_code}#{group_code}#{letters.join}"
    end
    private_class_method :generate_body

    # @param position [Array, nil] a [meaning, value_map] pair or nil (N/A)
    # @param random [Random] source of randomness
    # @return [String] a permitted letter for the position (X for N/A positions)
    def self.sample_attribute(position, random)
      return 'X' if position.nil?

      (position.last.keys + ['X']).sample(random: random)
    end
    private_class_method :sample_attribute

    # Rewrites the redemption letter to a permitted value when the ED
    # cross-position rule applies to the sampled underlying.
    #
    # @param category_code [String]
    # @param group_code [String]
    # @param letters [Array<String>] the four sampled attribute letters (mutated)
    # @param random [Random] source of randomness
    # @return [void]
    def self.enforce_ed_rule(category_code, group_code, letters, random)
      return unless Tables.ed_rule_applies?(category_code, group_code, letters)

      rule = Tables::ED_REDEMPTION_RULE
      letters[rule[:redemption_position]] = rule[:allowed_redemptions].sample(random: random)
    end
    private_class_method :enforce_ed_rule

    private

    # @return [Hash]
    def components = { category_code:, group_code:, attr1:, attr2:, attr3:, attr4: }

    # @return [Boolean]
    def valid_format?
      super && valid_category? && valid_group? && valid_attributes?
    end

    # @return [Array<Symbol>]
    def detect_errors
      return super unless identifier

      errors = []
      errors << :invalid_category unless valid_category?
      errors << :invalid_group unless valid_group?
      errors << :invalid_attribute if errors.empty? && !valid_attributes?
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
      when :invalid_attribute
        attribute_error_message
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

    # @return [Boolean] true when every attribute letter is permitted for its
    #   position and the ED cross-position rule holds
    def valid_attributes?
      attribute_violations.empty?
    end

    # Positions (3-6) whose letter is not permitted by the attribute matrix or
    # the ED cross-position rule, as [position, letter] pairs.
    #
    # @return [Array<Array(Integer, String)>]
    def attribute_violations
      @attribute_violations ||= compute_attribute_violations
    end

    # @return [Array<Array(Integer, String)>]
    def compute_attribute_violations
      attributes = Tables.group(category_code, group_code)[:attributes]
      violations = attribute_letters.each_with_index.filter_map do |letter, index|
        [index + 3, letter] unless permitted_attribute?(attributes[index], letter)
      end
      (violations + ed_rule_violations).uniq
    end

    # @param position [Array, nil] a [meaning, value_map] pair or nil (N/A)
    # @param letter [String]
    # @return [Boolean]
    def permitted_attribute?(position, letter)
      return true if letter == 'X'
      return false if position.nil? # pure-N/A position accepts only X

      position.last.key?(letter)
    end

    # @return [Array<Array(Integer, String)>] the redemption position when the
    #   ED cross-position rule is violated, otherwise empty
    def ed_rule_violations
      return [] unless ed_rule_applies?

      rule = Tables::ED_REDEMPTION_RULE
      redemption = attribute_letters[rule[:redemption_position]]
      return [] if rule[:allowed_redemptions].include?(redemption)

      [[rule[:redemption_position] + 3, redemption]]
    end

    # @return [Boolean] true when this is an ED code whose underlying triggers
    #   the redemption restriction
    def ed_rule_applies?
      Tables.ed_rule_applies?(category_code, group_code, attribute_letters)
    end

    # @return [Array<String>] the four attribute letters (positions 3-6)
    def attribute_letters
      [attr1, attr2, attr3, attr4]
    end

    # @return [String] a message naming the offending positions/letters/group
    def attribute_error_message
      return 'Strategies require XXXX in positions 3-6' if category_code == 'K'

      offenders = attribute_violations.map { |position, letter| "position #{position} '#{letter}'" }.join(', ')
      "Invalid attribute(s) for group '#{category_code}#{group_code}': #{offenders}"
    end
  end
end

require_relative 'cfi/field'
require_relative 'cfi/attribute_set'
require_relative 'cfi/classification'
