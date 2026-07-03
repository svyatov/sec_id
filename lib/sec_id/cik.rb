# frozen_string_literal: true

module SecID
  # Central Index Key (CIK) - SEC identifier for entities filing with the SEC.
  # A 1-10 digit number that uniquely identifies entities in SEC systems.
  #
  # @note CIK identifiers have no check digit and validation is based solely on format.
  #
  # @see https://en.wikipedia.org/wiki/Central_Index_Key
  #
  # @example Validate a CIK
  #   SecID::CIK.valid?('0001521365')  #=> true
  #   SecID::CIK.valid?('1521365')     #=> true
  #
  # @example Normalize a CIK to 10 digits
  #   SecID::CIK.normalize('1521365')  #=> '0001521365'
  class CIK < Base
    # Human-readable name of the standard.
    FULL_NAME = 'Central Index Key'
    # Valid length(s) of a normalized identifier.
    ID_LENGTH = (1..10)
    # A representative valid identifier.
    EXAMPLE = '0001521365'
    # Pattern matching the identifier's permitted character set.
    VALID_CHARS_REGEX = /\A[0-9]+\z/

    # Regular expression for parsing CIK components.
    ID_REGEX = /\A
      (?=\d{1,10}\z)(?<padding>0*)(?<identifier>[1-9]\d{0,9})
    \z/x

    # @return [String, nil] the leading zeros in the CIK
    attr_reader :padding

    # @param cik [String, Integer] the CIK to parse
    def initialize(cik)
      cik_parts = parse(cik)
      @padding = cik_parts[:padding]
      @identifier = cik_parts[:identifier]
    end

    # @return [String] the normalized 10-digit CIK
    # @raise [InvalidFormatError]
    def normalized
      validate!
      @identifier.rjust(self.class::ID_LENGTH.max, '0')
    end

    # @return [self]
    # @raise [InvalidFormatError]
    def normalize!
      super
      @padding = @full_id[0, self.class::ID_LENGTH.max - @identifier.length]
      self
    end

    # @return [String]
    def to_s
      full_id
    end

    # Generates a random CIK: an integer rendered without leading zeros.
    #
    # @param random [Random] source of randomness
    # @return [String] a 1-10 digit CIK
    def self.generate_body(random)
      random.rand(1..9_999_999_999).to_s
    end
    private_class_method :generate_body
  end
end
