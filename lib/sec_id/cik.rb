# frozen_string_literal: true

module SecId
  # Central Index Key (CIK) - SEC identifier for entities filing with the SEC.
  # A 1-10 digit number that uniquely identifies entities in SEC systems.
  # CIK does not have a check digit, only format validation.
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
    # Regular expression for parsing CIK components.
    ID_REGEX = /\A
      (?=\d{1,10}\z)(?<padding>0*)(?<identifier>[1-9]\d{0,9})
    \z/x

    # @return [String, nil] the leading zeros in the CIK
    attr_reader :padding

    class << self
      # Normalizes a CIK to 10-digit padded format.
      #
      # @param id [String, Integer] the CIK to normalize
      # @return [String] the 10-digit padded CIK
      # @raise [InvalidFormatError] if the CIK format is invalid
      def normalize!(id)
        new(id).normalize!
      end
    end

    # Creates a new CIK instance.
    #
    # @param cik [String, Integer] the CIK to parse
    def initialize(cik)
      cik_parts = parse(cik)
      @padding = cik_parts[:padding]
      @identifier = cik_parts[:identifier]
    end

    # CIK does not have a check digit.
    #
    # @return [Boolean] always false for CIK
    def has_check_digit?
      false
    end

    # Validates the CIK format.
    #
    # @return [Boolean] true if the format is valid
    def valid_format?
      !identifier.nil?
    end

    # Normalizes the CIK to 10-digit format with leading zeros.
    #
    # @return [String] the normalized 10-digit CIK
    # @raise [InvalidFormatError] if the CIK format is invalid
    def normalize!
      raise InvalidFormatError, "CIK '#{full_number}' is invalid and cannot be normalized!" unless valid_format?

      @padding = '0' * (10 - @identifier.length)
      @full_number = @identifier.rjust(10, '0')
    end

    # Returns the string representation of the CIK.
    #
    # @return [String] the CIK string
    def to_s
      full_number
    end
    alias to_str to_s

    private

    # Parses the CIK string.
    # Overrides base to skip upcase (CIK is numeric only).
    #
    # @param cik_number [String, Integer] the CIK to parse
    # @return [MatchData, Hash] the regex match data or empty hash
    def parse(cik_number)
      @full_number = cik_number.to_s.strip
      @full_number.match(ID_REGEX) || {}
    end
  end
end
