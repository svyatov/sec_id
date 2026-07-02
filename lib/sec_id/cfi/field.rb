# frozen_string_literal: true

module SecID
  class CFI < Base
    # A single decoded CFI position: the category, the group, or one attribute.
    # Carries its raw CFI letter (`#code`), semantic symbol (`#name`), ISO label
    # (`#label`), and — for attributes — the group meaning it answers
    # (`#meaning`). Defines a `<name>?` predicate for every symbol in its domain,
    # so `category.equity?` is answerable while an out-of-domain predicate such
    # as `category.voting?` raises `NoMethodError`.
    #
    # Built by {Classification}; also usable on its own.
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
  end
end
