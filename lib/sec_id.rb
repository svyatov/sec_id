# frozen_string_literal: true

require 'set'
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

    # Parses a string into the most specific matching identifier instance.
    #
    # @param str [String, nil] the identifier string to parse
    # @param types [Array<Symbol>, nil] restrict to specific types (e.g. [:isin, :cusip])
    # @return [SecID::Base, nil] a valid identifier instance, or nil if no match
    # @raise [ArgumentError] if any key in types is unknown
    def parse(str, types: nil)
      types.nil? ? parse_any(str) : parse_from(str, types)
    end

    # Parses a string into the most specific matching identifier instance, raising on failure.
    #
    # @param str [String, nil] the identifier string to parse
    # @param types [Array<Symbol>, nil] restrict to specific types (e.g. [:isin, :cusip])
    # @return [SecID::Base] a valid identifier instance
    # @raise [InvalidFormatError] if no matching identifier type is found
    # @raise [ArgumentError] if any key in types is unknown
    def parse!(str, types: nil)
      parse(str, types: types) || raise(InvalidFormatError, parse_error_message(str, types))
    end

    private

    # @param klass [Class] the identifier class to register
    # @return [void]
    def register_identifier(klass)
      key = klass.name.split('::').last.downcase.to_sym
      identifier_map[key] = klass
      identifier_list << klass
      @detector = nil
    end

    # @return [SecID::Base, nil]
    def parse_any(str)
      key = detect(str).first
      key && self[key].new(str)
    end

    # @return [SecID::Base, nil]
    def parse_from(str, types)
      types.each do |key|
        instance = self[key].new(str)
        return instance if instance.valid?
      end
      nil
    end

    # @return [String]
    def parse_error_message(str, types)
      base = "No matching identifier type found for #{str.to_s.strip.inspect}"
      types ? "#{base} among #{types.inspect}" : base
    end

    # @return [Detector]
    def detector
      @detector ||= Detector.new(identifier_list)
    end

    # @return [Hash{Symbol => Class}]
    def identifier_map
      @identifier_map ||= {}
    end

    # @return [Array<Class>]
    def identifier_list
      @identifier_list ||= []
    end
  end
end

require 'sec_id/validation_result'
require 'sec_id/concerns/checkable'
require 'sec_id/base'
require 'sec_id/detector'
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
