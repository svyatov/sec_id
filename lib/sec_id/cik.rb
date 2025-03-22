# frozen_string_literal: true

module SecID
  # https://en.wikipedia.org/wiki/Central_Index_Key
  class CIK < Base
    ID_REGEX = /\A
      (?=\d{1,10}\z)(?<padding>0*)(?<identifier>[1-9]\d{0,9})
    \z/x

    attr_reader :padding

    def initialize(cik)
      cik_parts = parse cik
      @padding = cik_parts[:padding]
      @identifier = cik_parts[:identifier]
    end

    def valid?
      valid_format?
    end

    def valid_format?
      !identifier.nil?
    end

    def restore!
      raise InvalidFormatError, "CIK '#{full_number}' is invalid and cannot be restored!" unless valid_format?

      @padding = '0' * (10 - @identifier.length)
      @full_number = @identifier.rjust(10, '0')
    end
  end
end
