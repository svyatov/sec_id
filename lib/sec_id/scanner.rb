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
    def precompute
      build_candidate_partitions
      build_length_table
    end

    # Splits the registered classes by which CANDIDATE_RE group routes to them.
    #
    # @return [void]
    def build_candidate_partitions
      @fisn_classes = @classes.select { |k| k.short_name == 'FISN' }
      @occ_classes = @classes.select { |k| k.short_name == 'OCC' }
      @simple_classes = @classes - @fisn_classes - @occ_classes
    end

    # Builds a Hash mapping each possible length to the classes that accept it.
    #
    # @return [void]
    def build_length_table
      @candidates_by_length = Hash.new { |h, k| h[k] = [] }
      @classes.each do |klass|
        klass.length_values.each { |len| @candidates_by_length[len] << klass }
      end
      @candidates_by_length.each_value(&:freeze)
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
      Match.new(type: best.type_key, raw: raw, range: start_pos...end_pos, identifier: best.new(cleaned))
    end

    # @return [Class, nil]
    def best_match(cleaned, classes)
      return if classes.empty?

      candidates = (@candidates_by_length[cleaned.length] || []) & classes
      return if candidates.empty?

      validated = candidates.select { |k| cleaned.match?(k::VALID_CHARS_REGEX) && k.valid?(cleaned) }
      validated.min_by(&:detection_priority)
    end
  end
end
