# frozen_string_literal: true

module SecId
  class Base
    LETTERS = Set.new('A'..'Z').freeze

    attr_reader :identifier, :check_digit

    def self.valid?(id)
      new(id).valid?
    end

    def self.valid_format?(id)
      new(id).valid_format?
    end

    def self.restore!(id_without_check_digit)
      new(id_without_check_digit).restore!
    end

    def self.check_digit(id)
      new(id).calculate_check_digit
    end

    def to_s
      "#{identifier}#{check_digit}"
    end
    alias to_str to_s

    private

    def digitized_identifier
      @digitized_identifier ||= identifier.each_char.flat_map { |char| char_to_digits char }
    end

    def char_to_digits(char)
      return char.to_i unless LETTERS.include? char
      number = char.to_i(36)
      [number / 10, number % 10]
    end

    def mod_10(sum)
      (10 - (sum % 10)) % 10
    end
  end
end
