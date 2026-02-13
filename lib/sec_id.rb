# frozen_string_literal: true

require 'set'
require 'sec_id/version'

module SecId
  class Error < StandardError; end
  class InvalidFormatError < Error; end
  class InvalidCheckDigitError < Error; end
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

    private

    # @param klass [Class] the identifier class to register
    # @return [void]
    def register_identifier(klass)
      key = klass.name.split('::').last.downcase.to_sym
      identifier_map[key] = klass
      identifier_list << klass
      @detector = nil
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
require 'sec_id/concerns/normalizable'
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
