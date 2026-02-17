# frozen_string_literal: true

module SecID
  # Provides class-level metadata methods for identifier types.
  #
  # Including classes must define constants: `FULL_NAME`, `ID_LENGTH`, `EXAMPLE`.
  #
  # @example
  #   SecID::ISIN.short_name       #=> "ISIN"
  #   SecID::ISIN.full_name        #=> "International Securities Identification Number"
  #   SecID::ISIN.has_check_digit? #=> true
  module IdentifierMetadata
    # @api private
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods added when IdentifierMetadata is included.
    module ClassMethods
      # Returns the unqualified class name (e.g. "ISIN", "CUSIP").
      #
      # @return [String]
      def short_name
        name.split('::').last
      end

      # Returns the full human-readable standard name.
      #
      # @return [String]
      def full_name
        self::FULL_NAME
      end

      # Returns the fixed length or valid length range for identifiers of this type.
      #
      # @return [Integer, Range]
      def id_length
        self::ID_LENGTH
      end

      # Returns a representative valid identifier string.
      #
      # @return [String]
      def example
        self::EXAMPLE
      end

      # @return [Boolean] true if this identifier type uses a check digit
      def has_check_digit?
        ancestors.include?(SecID::Checkable)
      end
    end
  end
end
