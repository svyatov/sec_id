# frozen_string_literal: true

module SecID
  # Base class for securities identifiers that provides a common interface
  # for validation, normalization, and parsing.
  #
  # Subclasses must implement:
  # - ID_REGEX constant with named capture groups for parsing
  # - initialize method that calls parse and extracts components
  #
  # Subclasses with checksum should also include the Checkable concern,
  # which provides checksum validation, calculation, and restoration.
  #
  # @example Implementing a checksum identifier
  #   class MyIdentifier < Base
  #     include Checkable
  #
  #     ID_REGEX = /\A(?<identifier>[A-Z]{6})(?<checksum>\d)?\z/x
  #
  #     def initialize(id)
  #       parts = parse(id)
  #       @identifier = parts[:identifier]
  #       @checksum = parts[:checksum]&.to_i
  #     end
  #
  #     def calculate_checksum
  #       validate_format_for_calculation!
  #       mod10(some_algorithm)
  #     end
  #   end
  #
  # @example Implementing a non-checksum identifier
  #   class SimpleId < Base
  #     ID_REGEX = /\A(?<identifier>[A-Z]{6})\z/x
  #
  #     def initialize(id)
  #       parts = parse(id)
  #       @identifier = parts[:identifier]
  #     end
  #   end
  class Base
    include Normalizable
    include Validatable
    include Generatable

    # @return [String] the original input after normalization (stripped and uppercased)
    attr_reader :full_id

    # @return [String, nil] the main identifier portion (without checksum)
    attr_reader :identifier

    class << self
      # The type's registry symbol: `SecID[SecID::ISIN.type_key] == SecID::ISIN`.
      #
      # @return [Symbol] the registry key (e.g. :isin, :cusip)
      def type_key = @type_key ||= short_name.downcase.to_sym

      # Composite sort key ranking detection specificity: checksum types first,
      # then narrower length range, then registration order. A class the registry
      # never saw sorts last.
      #
      # @api private
      # @return [Array] frozen [checksum rank, length specificity, registration order]
      def detection_priority
        @detection_priority ||=
          [has_checksum? ? 0 : 1, length_specificity, SecID.identifiers.index(self) || Float::INFINITY].freeze
      end

      # @return [String] the unqualified class name (e.g. "ISIN", "CUSIP")
      def short_name = @short_name ||= name.split('::').last

      # @return [String] the full human-readable standard name
      def full_name = self::FULL_NAME

      # @return [Integer, Range, Array<Integer>] the fixed length, valid length range, or discrete valid lengths
      def id_length = self::ID_LENGTH

      # Valid length values, for length-table indexing. Integer wraps to a
      # one-element Array; Range and Array both yield their own elements.
      #
      # @return [Array<Integer>, Range]
      def length_values = (v = self::ID_LENGTH).is_a?(Integer) ? [v] : v

      # Specificity weight from ID_LENGTH: fewer valid lengths ranks more specific.
      #
      # @return [Integer]
      def length_specificity = (v = self::ID_LENGTH).is_a?(Integer) ? 1 : v.size

      # @return [String] a representative valid identifier string
      def example = self::EXAMPLE

      # @return [Boolean] true if this identifier type uses a checksum
      def has_checksum?
        return @has_checksum if defined?(@has_checksum)

        @has_checksum = ancestors.include?(SecID::Checkable)
      end

      # @deprecated Use {.has_checksum?}. Kept as a v7 bridge; removed in v8.
      #
      # @return [Boolean]
      def has_check_digit?
        SecID::Deprecation.warn(old: 'has_check_digit?', new: 'has_checksum?')
        has_checksum?
      end
    end

    # @api private
    def self.inherited(subclass)
      super
      # Skip anonymous classes and classes outside the SecID namespace (e.g. in tests)
      SecID.__send__(:register_identifier, subclass) if subclass.name&.start_with?('SecID::')
    end

    # Subclasses must override this method.
    #
    # @param _sec_id_number [String] the identifier string to parse
    # @raise [NotImplementedError] always raised in base class
    def initialize(_sec_id_number)
      raise NotImplementedError
    end

    # @param other [Object]
    # @return [Boolean]
    def ==(other)
      other.class == self.class && comparison_id == other.comparison_id
    end

    alias eql? ==

    # @return [Integer]
    def hash
      [self.class, comparison_id].hash
    end

    # Returns a hash representation of this identifier for serialization.
    #
    # @return [Hash] hash with :type, :full_id, :normalized, :valid, and :components keys
    def to_h
      {
        type: self.class.type_key,
        full_id: full_id,
        normalized: valid? ? normalized : nil,
        valid: valid?,
        components: components_with_deprecation_bridge
      }
    end

    # Returns a JSON-compatible hash representation.
    #
    # @return [Hash]
    def as_json(*)
      to_h
    end

    # Exposes the parsed components for `case/in` destructuring. Validity is not part of
    # the protocol: components of unparseable input are `nil`, and `SecID.parse` returning
    # `nil` is the validity guard.
    #
    # @param _keys [Array<Symbol>, nil] the keys the pattern requests; ignored
    # @return [Hash] the parsed components
    #
    # @example
    #   case SecID.parse('US5949181045')
    #   in SecID::ISIN[country_code:, nsin:] then [country_code, nsin]
    #   in nil then :invalid
    #   end #=> ['US', '594918104']
    def deconstruct_keys(_keys) = components_with_deprecation_bridge

    protected

    # @return [String]
    def comparison_id
      valid? ? normalized : full_id
    end

    private

    # Mirrors the canonical `:checksum` components key onto the deprecated `:check_digit`
    # key for the v7 bridge, when a checksum is present. The mirror reads `:checksum`, so the
    # deprecated `check_digit` reader never fires internally. Removed in v8 (revert `to_h` and
    # `deconstruct_keys` to call `components` directly).
    #
    # @return [Hash] the parsed components, with `:check_digit` added when `:checksum` is present
    def components_with_deprecation_bridge
      parsed = components
      parsed.key?(:checksum) ? parsed.merge(check_digit: parsed[:checksum]) : parsed
    end

    # @return [Hash]
    def components
      {}
    end

    # @param sec_id_number [String, #to_s] the identifier to parse
    # @return [MatchData, Hash] the regex match data or empty hash if no match
    def parse(sec_id_number)
      @full_id = sec_id_number.to_s.strip.upcase
      @full_id.match(self.class::ID_REGEX) || {}
    end
  end
end
