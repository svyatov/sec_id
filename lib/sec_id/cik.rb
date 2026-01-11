# frozen_string_literal: true

module SecId
  # https://en.wikipedia.org/wiki/Central_Index_Key
  class CIK
    ID_REGEX = /\A
      (?=\d{1,10}\z)(?<padding>0*)(?<identifier>[1-9]\d{0,9})
    \z/x

    attr_reader :full_number, :identifier, :padding

    class << self
      def valid?(id)
        new(id).valid?
      end

      def valid_format?(id)
        new(id).valid_format?
      end

      def normalize!(id)
        new(id).normalize!
      end
    end

    def initialize(cik)
      cik_parts = parse(cik)
      @padding = cik_parts[:padding]
      @identifier = cik_parts[:identifier]
    end

    def valid?
      valid_format?
    end

    def valid_format?
      !identifier.nil?
    end

    def normalize!
      raise InvalidFormatError, "CIK '#{full_number}' is invalid and cannot be normalized!" unless valid_format?

      @padding = '0' * (10 - @identifier.length)
      @full_number = @identifier.rjust(10, '0')
    end

    def to_s
      full_number
    end
    alias to_str to_s

    private

    def parse(cik_number)
      @full_number = cik_number.to_s.strip
      @full_number.match(ID_REGEX) || {}
    end
  end
end
