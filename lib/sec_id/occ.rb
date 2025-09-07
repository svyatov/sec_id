# frozen_string_literal: true

require 'date'

module SecId
  # https://en.wikipedia.org/wiki/Option_symbol#The_OCC_Option_Symbol
  # https://web.archive.org/web/20120507220143/http://www.theocc.com/components/docs/initiatives/symbology/symbology_initiative_v1_8.pdf
  class OCC
    ID_REGEX = /\A
      (?<initial>
        (?=.{1,6})(?<underlying>\d?[A-Z]{1,5}\d?)(?<padding>[ ]*))
      (?<date>\d{6})
      (?<type>[CP])
      (?<strike_mills>\d{8})
    \z/x

    attr_reader :full_symbol, :underlying, :date_str, :type

    def initialize(symbol)
      symbol_parts = parse symbol
      @initial = symbol_parts[:initial]
      @underlying = symbol_parts[:underlying]
      @date_str = symbol_parts[:date]
      @type = symbol_parts[:type]
      @strike_mills = symbol_parts[:strike_mills]
    end

    def date
      return @date if @date

      @date = Date.strptime(date_str, '%y%m%d') if date_str
    rescue Date::Error
      nil
    end
    alias date_obj date

    def strike
      @strike ||= @strike_mills.to_i / 1000.0
    end

    def valid?
      valid_format? && !date.nil?
    end

    def valid_format?
      !@initial.nil?
    end

    def normalize!
      raise InvalidFormatError, "OCC '#{full_symbol}' is invalid and cannot be normalized!" unless valid?

      @strike_mills.length > 8 && @strike_mills = format('%08d', @strike_mills.to_i)
      @initial.length < 6 && @initial = underlying.ljust(6, "\s")

      @full_symbol = "#{@initial}#{date_str}#{type}#{@strike_mills}"
    end

    def to_s
      full_symbol
    end
    alias to_str to_s

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

      # rubocop:disable Metrics/MethodLength
      def build(underlying:, date:, type:, strike:)
        initial = underlying.to_s.ljust(6, "\s")
        date = Date.parse(date.to_s) unless date.is_a?(Date)

        case strike
        when Numeric
          strike_mills = format('%08d', (strike * 1000).to_i)
        when /\A\d{8}\z/
          strike_mills = strike
        else
          raise ArgumentError, 'Strike must be numeric or an 8-char string!'
        end

        symbol = "#{initial}#{date.strftime('%y%m%d')}#{type}#{strike_mills}"
        new(symbol)
      end
      # rubocop:enable Metrics/MethodLength
    end

    private

    def parse(symbol)
      @full_symbol = symbol.to_s.strip
      @full_symbol.match(ID_REGEX) || {}
    end
  end
end
