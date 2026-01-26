# frozen_string_literal: true

module SecId
  # Provides normalize! class method delegation for identifiers that support normalization.
  # Include this module in classes that implement an instance-level normalize! method.
  #
  # @example
  #   class MyIdentifier < Base
  #     include Normalizable
  #
  #     def normalize!
  #       # implementation
  #     end
  #   end
  #
  #   MyIdentifier.normalize!('ABC123')  #=> normalized string
  module Normalizable
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
      # @raise [InvalidFormatError] if the identifier format is invalid
      def normalize!(id)
        new(id).normalize!
      end
    end
  end
end
