# frozen_string_literal: true

module SecID
  # Financial Instrument Short Name (FISN) - a human-readable short name for financial
  # instruments per ISO 18774.
  #
  # Format: Issuer Name/Abbreviated Instrument Description
  # - Total length: 1-35 characters
  # - Issuer: 1-15 characters (uppercase A-Z, digits 0-9, space)
  # - Separator: forward slash (/)
  # - Description: 1-19 characters (uppercase A-Z, digits 0-9, space)
  #
  # @see https://en.wikipedia.org/wiki/ISO_18774
  #
  # @example Validate a FISN
  #   SecID::FISN.valid?('APPLE INC/SH')  #=> true
  #   SecID::FISN.valid?('apple inc/sh')  #=> true (normalized to uppercase)
  #
  # @example Access FISN components
  #   fisn = SecID::FISN.new('APPLE INC/SH')
  #   fisn.issuer       #=> 'APPLE INC'
  #   fisn.description  #=> 'SH'
  class FISN < Base
    FULL_NAME = 'Financial Instrument Short Name'
    ID_LENGTH = (3..35)
    EXAMPLE = 'APPLE INC/SH'
    VALID_CHARS_REGEX = %r{\A[A-Z0-9 /]+\z}
    SEPARATORS = /-/

    # Regular expression for parsing FISN components.
    # Issuer: 1-15 chars, Description: 1-19 chars, Total: max 35 chars
    ID_REGEX = %r{\A
      (?<identifier>
        (?<issuer>[A-Z0-9 ]{1,15})
        /
        (?<description>[A-Z0-9 ]{1,19}))
    \z}x

    # Characters valid in a FISN segment (alphanumeric and space).
    FISN_CHARSET = (ALPHANUMERIC + [' ']).freeze

    # @return [String, nil] the issuer name portion (before the slash)
    attr_reader :issuer

    # @return [String, nil] the abbreviated instrument description (after the slash)
    attr_reader :description

    # @param fisn [String] the FISN string to parse
    def initialize(fisn)
      fisn_parts = parse(fisn)
      @identifier = fisn_parts[:identifier]
      @issuer = fisn_parts[:issuer]
      @description = fisn_parts[:description]
    end

    # @return [String]
    def to_s
      identifier.to_s
    end

    # Generates a random FISN: issuer (1-15 chars) + '/' + description (1-19 chars).
    #
    # @param random [Random] source of randomness
    # @return [String] a generated FISN, at most 35 characters
    def self.generate_body(random)
      "#{generate_part(random.rand(1..15), random)}/#{generate_part(random.rand(1..19), random)}"
    end
    private_class_method :generate_body

    # Generates a FISN segment whose first and last characters are not spaces,
    # so Base#parse's strip leaves both segments intact.
    #
    # @param length [Integer] the segment length
    # @param random [Random] source of randomness
    # @return [String] a segment of the given length
    def self.generate_part(length, random)
      chars = Array.new(length) { FISN_CHARSET.sample(random: random) }
      chars[0] = ALPHANUMERIC.sample(random: random)
      chars[-1] = ALPHANUMERIC.sample(random: random)
      chars.join
    end
    private_class_method :generate_part

    private

    # @return [Hash]
    def components = { issuer:, description: }
  end
end
