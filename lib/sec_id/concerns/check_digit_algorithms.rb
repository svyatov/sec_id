# frozen_string_literal: true

module SecId
  # Provides shared Luhn algorithm variants for check digit calculations.
  # Include this module in classes that need check digit calculation.
  #
  # All methods expect a reversed array of digits as input.
  #
  # @see https://en.wikipedia.org/wiki/Luhn_algorithm
  module CheckDigitAlgorithms
    # CUSIP/CEI style: "Double Add Double" algorithm.
    # Processes pairs of digits, doubling the first (even-positioned from right),
    # then summing both digit's div10mod10 values.
    #
    # @param digits [Array<Integer>] reversed array of digit values
    # @return [Integer] the Luhn sum
    def luhn_sum_double_add_double(digits)
      digits.each_slice(2).reduce(0) do |sum, (even, odd)|
        double_even = (even || 0) * 2
        sum + div10mod10(double_even) + div10mod10(odd || 0)
      end
    end

    # FIGI style: index-based doubling algorithm.
    # Doubles odd-indexed digits (from right), then sums div10mod10 values.
    #
    # @param digits [Array<Integer>] reversed array of digit values
    # @return [Integer] the Luhn sum
    def luhn_sum_indexed(digits)
      digits.each_with_index.reduce(0) do |sum, (digit, index)|
        digit *= 2 if index.odd?
        sum + div10mod10(digit)
      end
    end

    # ISIN style: standard Luhn with subtract-9 for values > 9.
    # Processes pairs of digits, doubling the first (even-positioned from right),
    # subtracting 9 if result > 9.
    #
    # @param digits [Array<Integer>] reversed array of digit values
    # @return [Integer] the Luhn sum
    def luhn_sum_standard(digits)
      digits.each_slice(2).reduce(0) do |sum, (even, odd)|
        double_even = (even || 0) * 2
        double_even -= 9 if double_even > 9
        sum + double_even + (odd || 0)
      end
    end

    # Converts identifier characters to reversed digit array using single-digit mapping.
    # Used by CUSIP, CEI, FIGI, and SEDOL.
    #
    # @param id [String] the identifier string
    # @return [Array<Integer>] reversed array of digit values
    def reversed_digits_single(id)
      id.each_char.map { |c| CHAR_TO_DIGIT.fetch(c) }.reverse!
    end

    # Converts identifier characters to reversed digit array using multi-digit mapping.
    # Used by ISIN where letters expand to two digits.
    #
    # @param id [String] the identifier string
    # @return [Array<Integer>] reversed array of digit values
    def reversed_digits_multi(id)
      id.each_char.flat_map { |c| CHAR_TO_DIGITS.fetch(c) }.reverse!
    end
  end
end
