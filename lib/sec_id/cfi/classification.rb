# frozen_string_literal: true

module SecID
  class CFI < Base
    # The decoded ISO 10962:2021 classification of a valid CFI, built by
    # {CFI#decode}. A frozen value object exposing the category, group, and each
    # attribute as {Field} objects, plus `#to_s` and `#to_h`/`#as_json`.
    #
    # @example Decode an equity CFI
    #   c = SecID::CFI.new('ESVUFR').decode
    #   c.category.name                     #=> :equity
    #   c.category.equity?                  #=> true
    #   c.group.label                       #=> "Common/Ordinary shares"
    #   c.attributes.voting_right.voting?   #=> true
    #   c.attributes.payment_status.label   #=> "Fully paid"
    #   c.to_s                              #=> "Equities / Common/Ordinary shares: Voting, ..."
    class Classification
      # @return [Field] the category field
      attr_reader :category

      # @return [Field] the group field
      attr_reader :group

      # @return [AttributeSet] the decoded attribute fields
      attr_reader :attributes

      # @param category_code [String]
      # @param group_code [String]
      # @param letters [Array<String>] the four attribute letters (positions 3-6)
      def initialize(category_code, group_code, letters)
        @category = build_category(category_code)
        @group = build_group(category_code, group_code)
        @attributes = build_attributes(category_code, group_code, letters)
        freeze
      end

      # Renders a human-readable classification string from the ISO labels.
      #
      # @return [String]
      def to_s
        values = attributes.map(&:label).join(', ')
        head = "#{category.label} / #{group.label}"
        values.empty? ? head : "#{head}: #{values}"
      end

      # @return [Hash{Symbol => Object}]
      def to_h
        { category: category.to_h, group: group.to_h, attributes: attributes.to_h }
      end

      # @return [Hash{Symbol => Object}]
      def as_json(*)
        to_h
      end

      private

      # @param code [String]
      # @return [Field]
      def build_category(code)
        name, label = Tables::CATEGORIES.fetch(code)
        domain = Tables::CATEGORIES.each_value.map(&:first)
        Field.new(code, name, label, domain)
      end

      # @param category_code [String]
      # @param code [String]
      # @return [Field]
      def build_group(category_code, code)
        group = Tables.group(category_code, code)
        domain = Tables::GROUPS.fetch(category_code).each_value.map { |definition| definition[:symbol] }
        Field.new(code, group[:symbol], group[:label], domain)
      end

      # @param category_code [String]
      # @param group_code [String]
      # @param letters [Array<String>]
      # @return [AttributeSet]
      def build_attributes(category_code, group_code, letters)
        positions = Tables.group(category_code, group_code)[:attributes]
        fields = positions.zip(letters).filter_map do |position, letter|
          build_attribute(position, letter) if position
        end
        AttributeSet.new(fields)
      end

      # @param position [Array(Symbol, Hash)] a [meaning, value_map] pair
      # @param letter [String]
      # @return [Field]
      def build_attribute(position, letter)
        meaning, value_map = position
        name, label = decode_value(value_map, letter)
        domain = value_map.each_value.map(&:first) + [:not_applicable]
        Field.new(letter, name, label, domain, meaning: meaning)
      end

      # @param value_map [Hash{String => Array}]
      # @param letter [String]
      # @return [Array(Symbol, String)] the value symbol and its ISO label
      def decode_value(value_map, letter)
        return [:not_applicable, 'Not applicable'] if letter == 'X'

        value_map.fetch(letter)
      end
    end
  end
end
