# frozen_string_literal: true

module SecID
  class CFI < Base
    # The ordered collection of decoded attribute {Field}s. Enumerable over the
    # fields; also answers each present meaning as a reader method (e.g.
    # `#voting_right`) and via `#[]` (nil-safe). Built by {Classification}.
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
  end
end
