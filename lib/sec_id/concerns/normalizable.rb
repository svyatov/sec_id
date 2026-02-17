# frozen_string_literal: true

module SecID
  # Provides normalization methods for identifier types.
  #
  # Including classes may override `SEPARATORS` (default `/[\s-]/`) and `#normalized`.
  module Normalizable
    SEPARATORS = /[\s-]/

    # @api private
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods added when Normalizable is included.
    module ClassMethods
      # Normalizes the identifier to its canonical format.
      #
      # @param id [String, #to_s] the identifier to normalize
      # @return [String] the normalized identifier
      # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
      def normalize(id)
        cleaned = id.to_s.strip.gsub(self::SEPARATORS, '')
        new(cleaned.upcase).normalized
      end

      # Returns a human-readable formatted string, or nil if invalid.
      #
      # @param id [String, #to_s] the identifier to format
      # @return [String, nil]
      def to_pretty_s(id)
        cleaned = id.to_s.strip.gsub(self::SEPARATORS, '')
        new(cleaned.upcase).to_pretty_s
      end
    end

    # Returns the canonical normalized form of this identifier.
    #
    # @return [String]
    # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
    def normalized
      validate!
      to_s
    end

    # @!method normalize
    #   @return [String]
    #   @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
    alias normalize normalized

    # Normalizes this identifier in place, updating {#full_id}.
    #
    # @return [self]
    # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
    def normalize!
      @full_id = normalized
      self
    end

    # Returns a human-readable formatted string, or nil if invalid.
    #
    # @return [String, nil]
    def to_pretty_s
      return nil unless valid?

      to_s
    end

    # @return [String]
    def to_s
      identifier.to_s
    end

    # @return [String]
    def to_str
      to_s
    end
  end
end
