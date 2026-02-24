# frozen_string_literal: true

require 'sec_id/version'

module SecID
  # Base error class for all SecID errors.
  class Error < StandardError; end

  # Raised for invalid format, length, or characters.
  class InvalidFormatError < Error; end

  # Raised when the check digit does not match the calculated value.
  class InvalidCheckDigitError < Error; end

  # Raised for type-specific structural errors (invalid prefix, category, group, BBAN, or date).
  class InvalidStructureError < Error; end

  # Raised when multiple identifier types match and on_ambiguous: :raise is used.
  class AmbiguousMatchError < Error; end

  class << self
    # Looks up an identifier class by its symbol key.
    #
    # @param key [Symbol] identifier type (e.g. :isin, :cusip)
    # @return [Class] the identifier class
    # @raise [ArgumentError] if key is unknown
    def [](key)
      identifier_map.fetch(key) do
        raise ArgumentError, "Unknown identifier type: #{key.inspect}"
      end
    end

    # Returns all registered identifier classes in load order.
    #
    # @return [Array<Class>]
    def identifiers
      identifier_list.dup
    end

    # Detects all identifier types that match the given string.
    #
    # @param str [String, nil] the identifier string to detect
    # @return [Array<Symbol>] matching type symbols sorted by specificity
    def detect(str)
      detector.call(str)
    end

    # Checks whether the string is a valid identifier.
    #
    # @param str [String, nil] the identifier string to validate
    # @param types [Array<Symbol>, nil] restrict to specific types (e.g. [:isin, :cusip])
    # @return [Boolean]
    # @raise [ArgumentError] if any key in types is unknown
    def valid?(str, types: nil)
      return detect(str).any? if types.nil?

      types.any? { |key| self[key].valid?(str) }
    end

    # @param text [String, nil] the text to scan
    # @param types [Array<Symbol>, nil] restrict to specific types
    # @return [Array<Match>]
    # @raise [ArgumentError] if any key in types is unknown
    def extract(text, types: nil)
      scan(text, types: types).to_a
    end

    # @param text [String, nil] the text to scan
    # @param types [Array<Symbol>, nil] restrict to specific types
    # @return [Enumerator<Match>] if no block given
    # @yieldparam match [Match]
    # @raise [ArgumentError] if any key in types is unknown
    def scan(text, types: nil, &)
      classes = types&.map { |key| self[key] }
      scanner.call(text, classes: classes, &)
    end

    # @param str [String, nil] the identifier string to explain
    # @param types [Array<Symbol>, nil] restrict to specific types
    # @return [Hash] hash with :input and :candidates keys
    def explain(str, types: nil)
      input = str.to_s.strip
      target_keys = types || identifier_list.map { |k| k.short_name.downcase.to_sym }
      candidates = target_keys.map do |key|
        instance = self[key].new(input)
        { type: key, valid: instance.valid?, errors: instance.errors.details }
      end
      { input: input, candidates: candidates }
    end

    # @param str [String, nil] the identifier string to parse
    # @param types [Array<Symbol>, nil] restrict to specific types (e.g. [:isin, :cusip])
    # @param on_ambiguous [:first, :raise, :all] how to handle multiple matches
    # @return [SecID::Base, nil, Array<SecID::Base>] depends on on_ambiguous mode
    # @raise [AmbiguousMatchError] when on_ambiguous: :raise and multiple types match
    def parse(str, types: nil, on_ambiguous: :first)
      case on_ambiguous
      when :first then types.nil? ? parse_any(str) : parse_from(str, types)
      when :raise then parse_strict(str, types)
      when :all   then parse_all(str, types)
      else raise ArgumentError, "Unknown on_ambiguous mode: #{on_ambiguous.inspect}"
      end
    end

    # @param str [String, nil] the identifier string to parse
    # @param types [Array<Symbol>, nil] restrict to specific types (e.g. [:isin, :cusip])
    # @param on_ambiguous [:first, :raise, :all] how to handle multiple matches
    # @return [SecID::Base, Array<SecID::Base>] depends on on_ambiguous mode
    # @raise [InvalidFormatError] if no matching identifier type is found
    # @raise [AmbiguousMatchError] when on_ambiguous: :raise and multiple types match
    def parse!(str, types: nil, on_ambiguous: :first)
      result = parse(str, types: types, on_ambiguous: on_ambiguous)

      if on_ambiguous == :all
        raise(InvalidFormatError, parse_error_message(str, types)) if result.empty?

        return result
      end

      result || raise(InvalidFormatError, parse_error_message(str, types))
    end

    private

    # @return [void]
    def register_identifier(klass)
      key = klass.name.split('::').last.downcase.to_sym
      identifier_map[key] = klass
      identifier_list << klass
      @detector = nil
      @scanner = nil
    end

    def parse_any(str)
      key = detect(str).first
      key && self[key].new(str)
    end

    def parse_from(str, types)
      types.each do |key|
        instance = self[key].new(str)
        return instance if instance.valid?
      end
      nil
    end

    def parse_strict(str, types)
      candidates = resolve_candidates(str, types)
      raise AmbiguousMatchError, ambiguous_message(str, candidates) if candidates.size > 1

      candidates.first && self[candidates.first].new(str)
    end

    def parse_all(str, types)
      resolve_candidates(str, types).map { |key| self[key].new(str) }
    end

    # @return [Array<Symbol>]
    def resolve_candidates(str, types)
      types ? types.select { |key| self[key].valid?(str) } : detect(str)
    end

    # @return [String]
    def ambiguous_message(str, candidates)
      "Ambiguous identifier #{str.to_s.strip.inspect}: matches #{candidates.inspect}"
    end

    # @return [String]
    def parse_error_message(str, types)
      base = "No matching identifier type found for #{str.to_s.strip.inspect}"
      types ? "#{base} among #{types.inspect}" : base
    end

    def detector = @detector ||= Detector.new(identifier_list)
    def scanner = @scanner ||= Scanner.new(identifier_list)
    def identifier_map = @identifier_map ||= {}
    def identifier_list = @identifier_list ||= []
  end
end

require 'sec_id/errors'
require 'sec_id/concerns/normalizable'
require 'sec_id/concerns/validatable'
require 'sec_id/concerns/checkable'
require 'sec_id/base'
require 'sec_id/detector'
require 'sec_id/scanner'
require 'sec_id/isin'
require 'sec_id/cusip'
require 'sec_id/sedol'
require 'sec_id/figi'
require 'sec_id/lei'
require 'sec_id/iban'
require 'sec_id/cik'
require 'sec_id/occ'
require 'sec_id/wkn'
require 'sec_id/valoren'
require 'sec_id/cei'
require 'sec_id/cfi'
require 'sec_id/fisn'
