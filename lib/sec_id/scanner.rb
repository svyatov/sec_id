# frozen_string_literal: true

module SecID
  # Immutable value object representing a matched identifier found in text.
  Match = Data.define(:type, :raw, :range, :identifier)

  # Finds securities identifiers in freeform text using regex candidate extraction,
  # length/charset pre-filtering, and cursor-based overlap prevention.
  #
  # @api private
  class Scanner
    # Composite regex for candidate extraction.
    #
    # Three named groups tried left-to-right via alternation:
    # - fisn: contains `/` (unique FISN delimiter)
    # - occ: contains structural spaces + date/type pattern
    # - simple: common alphanumeric tokens (covers all other types)
    CANDIDATE_RE = %r{
      (?<![A-Za-z0-9*@\#/.$])
      (?:
        (?<fisn>[A-Za-z0-9](?:[A-Za-z0-9 ]{0,33}[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9 ]{0,33}[A-Za-z0-9])?)
        |
        (?<occ>[A-Za-z]{1,6}\ {1,5}\d{6}[CcPp]\d{8})
        |
        (?<simple>[A-Za-z0-9*@\#](?:[A-Za-z0-9*@\#-]{0,40}[A-Za-z0-9*@\#])?)
      )
      (?![A-Za-z0-9*@\#.])
    }x

    # @param identifier_list [Array<Class>] registered identifier classes
    def initialize(identifier_list)
      @classes = identifier_list.dup.freeze
      precompute
    end

    # Scans text for identifiers, yielding or returning matches.
    #
    # @param text [String, nil] the text to scan
    # @param classes [Array<Class>, nil] restrict to specific classes
    # @return [Enumerator<Match>] if no block given
    # @yieldparam match [Match]
    def call(text, classes: nil, &block)
      return enum_for(:call, text, classes: classes) unless block

      input = text.to_s
      return if input.empty?

      scan_text(input, classes || @classes, &block)
    end

    private

    # @return [void]
    def precompute # rubocop:disable Metrics/AbcSize
      build_key_table
      build_priority_table
      @fisn_classes = @classes.select { |k| k.short_name == 'FISN' }
      @occ_classes = @classes.select { |k| k.short_name == 'OCC' }
      @simple_classes = @classes - @fisn_classes - @occ_classes
      @candidates_by_length = Hash.new { |h, k| h[k] = [] }
      @classes.each do |klass|
        id_length = klass::ID_LENGTH
        lengths = id_length.is_a?(Range) ? id_length : [id_length]
        lengths.each { |len| @candidates_by_length[len] << klass }
      end
      @candidates_by_length.each_value(&:freeze)
    end

    # @return [void]
    def build_key_table
      @key_for = {}
      @classes.each { |klass| @key_for[klass] = klass.short_name.downcase.to_sym }
      @key_for.freeze
    end

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

    # @param input [String]
    # @param target_classes [Array<Class>]
    # @return [void]
    def scan_text(input, target_classes)
      pos = 0
      while pos < input.length
        match_data = CANDIDATE_RE.match(input, pos)
        break unless match_data

        result = identify_candidate(match_data, target_classes)
        if result
          yield result
          pos = match_data.end(0)
        else
          pos = match_data.begin(0) + 1
        end
      end
    end

    # @param match_data [MatchData]
    # @param target_classes [Array<Class>]
    # @return [Match, nil]
    def identify_candidate(match_data, target_classes)
      raw = match_data[0]
      start_pos = match_data.begin(0)

      if match_data[:fisn]
        try_classes(raw, raw.upcase, start_pos, target_classes & @fisn_classes)
      elsif match_data[:occ]
        try_classes(raw, raw.upcase, start_pos, target_classes & @occ_classes)
      else
        cleaned = raw.gsub('-', '').upcase
        try_classes(raw, cleaned, start_pos, target_classes & @simple_classes)
      end
    end

    # @return [Match, nil]
    def try_classes(raw, cleaned, start_pos, classes)
      best = best_match(cleaned, classes)
      return unless best

      end_pos = start_pos + raw.length
      Match.new(type: @key_for[best], raw: raw, range: start_pos...end_pos, identifier: best.new(cleaned))
    end

    # @return [Class, nil]
    def best_match(cleaned, classes)
      return if classes.empty?

      candidates = (@candidates_by_length[cleaned.length] || []) & classes
      return if candidates.empty?

      validated = candidates.select { |k| cleaned.match?(k::VALID_CHARS_REGEX) && k.valid?(cleaned) }
      validated.min_by { |k| @priority_for[k] }
    end
  end
end
