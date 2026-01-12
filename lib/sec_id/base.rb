# frozen_string_literal: true

module SecId
  CHAR_TO_DIGITS = {
    '0' => 0,      '1' => 1,      '2' => 2,      '3' => 3,      '4' => 4,
    '5' => 5,      '6' => 6,      '7' => 7,      '8' => 8,      '9' => 9,
    'A' => [1, 0], 'B' => [1, 1], 'C' => [1, 2], 'D' => [1, 3], 'E' => [1, 4],
    'F' => [1, 5], 'G' => [1, 6], 'H' => [1, 7], 'I' => [1, 8], 'J' => [1, 9],
    'K' => [2, 0], 'L' => [2, 1], 'M' => [2, 2], 'N' => [2, 3], 'O' => [2, 4],
    'P' => [2, 5], 'Q' => [2, 6], 'R' => [2, 7], 'S' => [2, 8], 'T' => [2, 9],
    'U' => [3, 0], 'V' => [3, 1], 'W' => [3, 2], 'X' => [3, 3], 'Y' => [3, 4], 'Z' => [3, 5],
    '*' => [3, 6], '@' => [3, 7], '#' => [3, 8]
  }.freeze

  CHAR_TO_DIGIT = {
    '0' => 0,  '1' => 1,  '2' => 2,  '3' => 3,  '4' =>  4,
    '5' => 5,  '6' => 6,  '7' => 7,  '8' => 8,  '9' =>  9,
    'A' => 10, 'B' => 11, 'C' => 12, 'D' => 13, 'E' => 14,
    'F' => 15, 'G' => 16, 'H' => 17, 'I' => 18, 'J' => 19,
    'K' => 20, 'L' => 21, 'M' => 22, 'N' => 23, 'O' => 24,
    'P' => 25, 'Q' => 26, 'R' => 27, 'S' => 28, 'T' => 29,
    'U' => 30, 'V' => 31, 'W' => 32, 'X' => 33, 'Y' => 34, 'Z' => 35,
    '*' => 36, '@' => 37, '#' => 38
  }.freeze

  class Base
    attr_reader :full_number, :identifier, :check_digit

    class << self
      def valid?(id)
        new(id).valid?
      end

      def valid_format?(id)
        new(id).valid_format?
      end

      def restore!(id_without_check_digit)
        new(id_without_check_digit).restore!
      end

      def check_digit(id)
        new(id).calculate_check_digit
      end
    end

    def initialize(_sec_id_number)
      raise NotImplementedError
    end

    def valid?
      return false unless valid_format?

      check_digit == calculate_check_digit
    end

    def valid_format?
      identifier ? true : false
    end

    def restore!
      @check_digit = calculate_check_digit
      @full_number = to_s
    end

    def calculate_check_digit
      raise NotImplementedError
    end

    def to_s
      "#{identifier}#{check_digit}"
    end
    alias to_str to_s

    private

    def id_digits
      raise NotImplementedError
    end

    def parse(sec_id_number)
      @full_number = sec_id_number.to_s.strip.upcase
      @full_number.match(self.class::ID_REGEX) || {}
    end

    def char_to_digits(char)
      SecId::CHAR_TO_DIGITS.fetch(char)
    end

    def char_to_digit(char)
      SecId::CHAR_TO_DIGIT.fetch(char)
    end

    def mod10(sum)
      (10 - (sum % 10)) % 10
    end

    def div10mod10(number)
      (number / 10) + (number % 10)
    end

    def mod97(numeric_string)
      98 - (numeric_string.to_i % 97)
    end
  end
end
