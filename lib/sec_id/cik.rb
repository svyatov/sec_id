# frozen_string_literal: true

module SecId
  # Central Index Key (CIK) - SEC identifier for entities filing with the SEC.
  # A 1-10 digit number that uniquely identifies entities in SEC systems.
  #
  # @note CIK identifiers have no check digit. The {#has_check_digit?} method
  #   returns false and validation is based solely on format.
  #
  # @see https://en.wikipedia.org/wiki/Central_Index_Key
  #
  # @example Validate a CIK
  #   SecId::CIK.valid?('0001521365')  #=> true
  #   SecId::CIK.valid?('1521365')     #=> true
  #
  # @example Normalize a CIK to 10 digits
  #   SecId::CIK.normalize!('1521365')  #=> '0001521365'
  class CIK < Base
    include Normalizable

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

    # Normalizes the CIK to a 10-digit zero-padded format.
    # Updates both @full_number and @padding to reflect the normalized state.
    #
    # @return [String] the normalized 10-digit CIK
    # @raise [InvalidFormatError] if the CIK format is invalid
    def normalize!
      raise InvalidFormatError, "CIK '#{full_number}' is invalid and cannot be normalized!" unless valid_format?

      @full_number = @identifier.rjust(10, '0')
      @padding = @full_number[0, 10 - @identifier.length]
      @full_number
    end

    # @return [String]
    def to_s
      full_number
    end
    alias to_str to_s
  end
end
