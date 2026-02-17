# frozen_string_literal: true

module SecID
  # Detects which identifier types match a given string using a three-stage
  # pipeline that eliminates most candidates before calling `valid?`.
  #
  # Stage 1 — Special-character dispatch (O(1)):
  #   Strings containing `/`, ` `, or `*@#` route to the only types accepting those chars.
  #
  # Stage 2 — Length lookup (O(1) hash access):
  #   Pre-computed table maps each possible length to candidate classes.
  #
  # Stage 3 — Charset pre-filter:
  #   Survivors are filtered by their VALID_CHARS_REGEX before calling `valid?`.
  #
  # Typical result: 1-2 `valid?` calls instead of 13.
  #
  # @api private
  class Detector
    # @param identifier_list [Array<Class>] registered identifier classes
    def initialize(identifier_list)
      @classes = identifier_list.dup.freeze
      precompute
    end

    # Detects all matching identifier types for the given string.
    #
    # @param str [String, nil] the identifier string to detect
    # @return [Array<Symbol>] matching type symbols sorted by specificity
    def call(str)
      input = str.to_s.strip
      return [] if input.empty?

      upcased = input.upcase
      candidates = filter_candidates(upcased)
      validate_and_sort(input, candidates)
    end

    private

    # Runs stages 1-3 to narrow candidate classes.
    #
    # @param upcased [String]
    # @return [Array<Class>]
    def filter_candidates(upcased)
      candidates = stage1_special_chars(upcased) || stage2_length(upcased.length)
      return candidates if candidates.empty?

      stage3_charset(upcased, candidates)
    end

    # Validates candidates and returns sorted symbol keys.
    #
    # @param input [String]
    # @param candidates [Array<Class>]
    # @return [Array<Symbol>]
    def validate_and_sort(input, candidates)
      matches = candidates.select { |klass| klass.valid?(input) }
      matches.sort_by! { |klass| @priority_for[klass] }
      matches.map! { |klass| @key_for[klass] }
    end

    # @return [void]
    def precompute
      build_discriminator_sets
      build_length_table
      build_priority_table
      build_key_table
    end

    # Classifies types by which special characters their VALID_CHARS_REGEX accepts.
    #
    # @return [void]
    def build_discriminator_sets
      @slash_types = @classes.select { |k| accepts_char?(k, '/') }
      space_types = @classes.select { |k| accepts_char?(k, ' ') }
      @space_only_types = space_types - @slash_types
      @special_types = @classes.select { |k| accepts_char?(k, '*') }
    end

    # Builds a Hash mapping each possible length to the classes that accept it.
    #
    # @return [void]
    def build_length_table
      @candidates_by_length = Hash.new { |h, k| h[k] = [] }
      @classes.each do |klass|
        id_length = klass::ID_LENGTH
        lengths = id_length.is_a?(Range) ? id_length : [id_length]
        lengths.each { |len| @candidates_by_length[len] << klass }
      end
      @candidates_by_length.each_value(&:freeze)
    end

    # Builds composite sort keys: check-digit types first, then smaller range, then load order.
    #
    # @return [void]
    def build_priority_table
      @priority_for = {}
      @classes.each_with_index do |klass, index|
        check_digit_rank = klass.has_check_digit? ? 0 : 1
        id_length = klass::ID_LENGTH
        range_size = id_length.is_a?(Range) ? id_length.size : 1
        @priority_for[klass] = [check_digit_rank, range_size, index].freeze
      end
      @priority_for.freeze
    end

    # Maps each class to its registry symbol key.
    #
    # @return [void]
    def build_key_table
      @key_for = {}
      @classes.each { |klass| @key_for[klass] = klass.short_name.downcase.to_sym }
      @key_for.freeze
    end

    # Stage 1: route strings with special characters to the only types that accept them.
    # Returns nil if no special chars found (fall through to stage 2).
    #
    # @param upcased [String]
    # @return [Array<Class>, nil]
    def stage1_special_chars(upcased)
      return @slash_types if upcased.include?('/')
      return @space_only_types if upcased.include?(' ')
      return @special_types if upcased.match?(/[*@#]/)

      nil
    end

    # Stage 2: look up candidates by string length.
    #
    # @param length [Integer]
    # @return [Array<Class>]
    def stage2_length(length)
      @candidates_by_length[length] || []
    end

    # Stage 3: filter candidates by character set.
    #
    # @param upcased [String]
    # @param candidates [Array<Class>]
    # @return [Array<Class>]
    def stage3_charset(upcased, candidates)
      candidates.select { |klass| upcased.match?(klass::VALID_CHARS_REGEX) }
    end

    # Tests whether a class's VALID_CHARS_REGEX accepts a given character.
    #
    # @param klass [Class]
    # @param char [String] single character
    # @return [Boolean]
    def accepts_char?(klass, char)
      char.match?(klass::VALID_CHARS_REGEX)
    end
  end
end
