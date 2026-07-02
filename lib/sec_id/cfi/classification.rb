# frozen_string_literal: true

module SecID
  class CFI < Base
    # The decoded ISO 10962:2021 classification of a valid CFI, built by
    # {CFI#decode}. A frozen value object exposing the category and group as
    # symbols, the decoded attributes (keyed by each position's group-specific
    # meaning), the authoritative ISO/SIX label strings, and a convenience
    # predicate per distinct attribute value.
    #
    # Predicates are value-level: `#voting?` is true when *any* decoded position
    # holds the `:voting` value, regardless of which position. A value symbol
    # (e.g. `:others`) can appear under more than one meaning, so a predicate
    # answers true on any match. For position precision, read {#attributes}.
    #
    # @example Decode an equity CFI
    #   c = SecID::CFI.new('ESVUFR').decode
    #   c.category        #=> :equity
    #   c.category_label  #=> "Equities"
    #   c.group           #=> :common_shares
    #   c.attributes      #=> { voting_right: :voting, ownership_restrictions: :free_of_restrictions,
    #                     #      payment_status: :fully_paid, form: :registered }
    #   c.voting?         #=> true
    #   c.fully_paid?     #=> true
    #   c.to_s            #=> "Equities / Common/Ordinary shares: Voting, Free of restrictions, ..."
    class Classification
      # @return [Symbol] the category symbol (e.g. :equity)
      attr_reader :category

      # @return [String] the authoritative ISO label for the category
      attr_reader :category_label

      # @return [Symbol] the group symbol (e.g. :common_shares)
      attr_reader :group

      # @return [String] the authoritative ISO label for the group
      attr_reader :group_label

      # @return [Hash{Symbol => Symbol}] decoded attributes keyed by each
      #   position's group-specific meaning; X decodes to :not_applicable and
      #   pure-N/A positions are omitted
      attr_reader :attributes

      # @return [Hash{Symbol => String}] the ISO label for each decoded attribute value
      attr_reader :attribute_labels

      # @param category_code [String]
      # @param group_code [String]
      # @param letters [Array<String>] the four attribute letters (positions 3-6)
      def initialize(category_code, group_code, letters)
        @category, @category_label = CFITables::CATEGORIES.fetch(category_code)
        group = CFITables.group(category_code, group_code)
        @group = group[:symbol]
        @group_label = group[:label]
        decode_attributes(group[:attributes], letters)
        freeze
      end

      # Renders a human-readable classification string from the ISO labels.
      #
      # @return [String]
      def to_s
        values = attribute_labels.values.join(', ')
        return "#{category_label} / #{group_label}" if values.empty?

        "#{category_label} / #{group_label}: #{values}"
      end

      # Returns a hash representation of this classification for serialization.
      #
      # @return [Hash] hash with :category, :category_label, :group,
      #   :group_label, :attributes, and :attribute_labels keys
      def to_h
        {
          category: category,
          category_label: category_label,
          group: group,
          group_label: group_label,
          attributes: attributes,
          attribute_labels: attribute_labels
        }
      end

      # Returns a JSON-compatible hash representation.
      #
      # @return [Hash]
      def as_json(*)
        to_h
      end

      # One `<value>?` predicate per distinct attribute value symbol in the
      # tables — true when any decoded attribute holds that value.
      CFITables::VALUE_SYMBOLS.each do |symbol|
        define_method(:"#{symbol}?") { attributes.value?(symbol) }
      end

      private

      # @param positions [Array] the group's four position definitions
      # @param letters [Array<String>] the four attribute letters
      # @return [void]
      def decode_attributes(positions, letters)
        @attributes = {}
        @attribute_labels = {}
        positions.each_with_index do |position, index|
          next if position.nil? # pure-N/A position omitted

          meaning = position.first
          @attributes[meaning], @attribute_labels[meaning] = decode_value(position.last, letters[index])
        end
        @attributes.freeze
        @attribute_labels.freeze
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
