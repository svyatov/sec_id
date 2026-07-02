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
      # A single decoded position: the category, the group, or one attribute.
      # Carries its raw CFI letter (`#code`), semantic symbol (`#name`), ISO
      # label (`#label`), and — for attributes — the group meaning it answers
      # (`#meaning`). Defines a `<name>?` predicate for every symbol in its
      # domain, so `category.equity?` is answerable while an out-of-domain
      # predicate such as `category.voting?` raises `NoMethodError`.
      class Field
        # @return [String] the raw CFI letter (e.g. "E", "V")
        attr_reader :code

        # @return [Symbol] the semantic symbol (e.g. :equity, :voting)
        attr_reader :name

        # @return [String] the authoritative ISO label
        attr_reader :label

        # @return [Symbol, nil] the group meaning for attribute fields, nil for category/group
        attr_reader :meaning

        # @param code [String]
        # @param name [Symbol]
        # @param label [String]
        # @param domain [Array<Symbol>] the symbols this field may hold; one `<symbol>?` predicate per entry
        # @param meaning [Symbol, nil]
        def initialize(code, name, label, domain, meaning: nil)
          @code = code
          @name = name
          @label = label
          @meaning = meaning
          domain.each { |symbol| define_singleton_method(:"#{symbol}?") { @name == symbol } }
          freeze
        end

        # @return [String] the ISO label
        def to_s
          label
        end

        # @return [Hash{Symbol => Object}]
        def to_h
          { code: code, name: name, label: label }
        end

        # @return [Hash{Symbol => Object}]
        def as_json(*)
          to_h
        end
      end

      # The ordered collection of decoded attribute {Field}s. Enumerable over
      # the fields; also answers each present meaning as a reader method (e.g.
      # `#voting_right`) and via `#[]` (nil-safe).
      class AttributeSet
        include Enumerable

        # @param fields [Array<Field>] one per non-N/A position, in order
        def initialize(fields)
          @fields = fields
          fields.each { |field| define_singleton_method(field.meaning) { field } }
          freeze
        end

        # @yieldparam field [Field]
        # @return [Enumerator, self]
        def each(&block)
          return to_enum(:each) unless block

          @fields.each(&block)
          self
        end

        # @param meaning [Symbol]
        # @return [Field, nil]
        def [](meaning)
          find { |field| field.meaning == meaning }
        end

        # @return [Boolean]
        def empty?
          @fields.empty?
        end

        # @return [Hash{Symbol => Hash}]
        def to_h
          @fields.to_h { |field| [field.meaning, field.to_h] }
        end

        # @return [Hash{Symbol => Hash}]
        def as_json(*)
          to_h
        end
      end

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
        name, label = CFITables::CATEGORIES.fetch(code)
        domain = CFITables::CATEGORIES.each_value.map(&:first)
        Field.new(code, name, label, domain)
      end

      # @param category_code [String]
      # @param code [String]
      # @return [Field]
      def build_group(category_code, code)
        group = CFITables.group(category_code, code)
        domain = CFITables::GROUPS.fetch(category_code).each_value.map { |definition| definition[:symbol] }
        Field.new(code, group[:symbol], group[:label], domain)
      end

      # @param category_code [String]
      # @param group_code [String]
      # @param letters [Array<String>]
      # @return [AttributeSet]
      def build_attributes(category_code, group_code, letters)
        positions = CFITables.group(category_code, group_code)[:attributes]
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
