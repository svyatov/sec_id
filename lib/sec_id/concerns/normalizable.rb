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
    end

    # Returns the canonical normalized form of this identifier.
    #
    # @return [String]
    # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
    def normalized
      validate!
      to_s
    end
    alias normalize normalized

    # Normalizes this identifier in place, updating {#full_id}.
    #
    # @return [self]
    # @raise [InvalidFormatError, InvalidCheckDigitError, InvalidStructureError]
    def normalize!
      @full_id = normalized
      self
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
