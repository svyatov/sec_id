# frozen_string_literal: true

module SecID
  # Provides generation of new, format-valid identifiers for use as test fixtures.
  #
  # Including classes define a class-level `generate_body(random)` returning a valid
  # body (the identifier without its checksum). The default {ClassMethods#generate}
  # builds an instance from that body and restores the checksum for checksum types.
  # Types whose shape is not "body (+ checksum)" compose the full identifier in
  # `generate_body` (CFI, FISN) or override `generate` entirely (OCC).
  #
  # @note Generated identifiers are valid in format only — they are not real,
  #   registered securities. Country codes, prefixes, dates, and attributes are random.
  #
  # @example Generate a fixture
  #   SecID::ISIN.generate           #=> #<SecID::ISIN ...> (valid?)
  #   SecID::ISIN.generate.valid?    #=> true
  #
  # @example Reproducible output via a seeded Random
  #   SecID::ISIN.generate(random: Random.new(42)) == SecID::ISIN.generate(random: Random.new(42))
  module Generatable
    # Uppercase letters A-Z.
    ALPHA = ('A'..'Z').to_a.freeze

    # Decimal digits 0-9.
    DIGITS = ('0'..'9').to_a.freeze

    # Alphanumeric characters (digits then uppercase letters).
    ALPHANUMERIC = (DIGITS + ALPHA).freeze

    # Extends the including identifier class with the concern's class methods.
    #
    # @param base [Class] the identifier class including this concern
    # @return [void]
    # @api private
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods added when Generatable is included.
    module ClassMethods
      # Generates a new, format-valid identifier instance.
      #
      # @note Generated identifiers are valid in format only — they are not real,
      #   registered securities.
      #
      # @param random [Random] seedable source for reproducible output
      # @return [self] a generated instance of the identifier type (e.g. {SecID::ISIN}) for which `valid?` is true
      def generate(random: Random.new)
        instance = new(generate_body(random))
        has_checksum? ? instance.restore! : instance
      end

      private

      # Subclasses must implement this to return a valid body (identifier without checksum),
      # unless they override {#generate} entirely (as OCC does).
      #
      # @param _random [Random] source of randomness
      # @return [String] the generated body
      # @raise [NotImplementedError] if the identifier type does not implement it
      def generate_body(_random)
        raise NotImplementedError, "#{self} must implement .generate_body"
      end

      # @param charset [Array<String>] characters to draw from
      # @param length [Integer] number of characters to generate
      # @param random [Random] source of randomness
      # @return [String] a random string of the given length
      def random_string(charset, length, random:)
        Array.new(length) { charset.sample(random: random) }.join
      end
    end
  end
end
