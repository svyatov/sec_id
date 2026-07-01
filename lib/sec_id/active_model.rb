# frozen_string_literal: true

require 'sec_id'

begin
  require 'active_model'
rescue LoadError => e
  raise LoadError, 'sec_id/active_model requires ActiveModel, which could not be loaded. Add ' \
                   '`gem "activemodel"` to your Gemfile (or use this inside a Rails app) before ' \
                   "requiring 'sec_id/active_model'. (#{e.message})"
end

# ActiveModel validator for securities identifiers, registered under the `sec_id` key.
#
# It validates a value against a single type (`type:`), an allowlist (`types:`), or any of the
# supported identifier types (no key). Validation is strict by default; separator-lenient
# canonicalization and specific failure reasons are opt-in via `normalize:` and `details:`.
#
# This file is loaded automatically inside Rails (via {SecID::Railtie}) and must be required
# explicitly (`require 'sec_id/active_model'`) in non-Rails ActiveModel stacks. It is never on
# the default `require 'sec_id'` path, so the gem keeps its zero runtime dependencies.
#
# @example Validate a single type
#   validates :isin, sec_id: { type: :isin }
#
# @example Validate against an allowlist
#   validates :ref, sec_id: { types: %i[isin cusip] }
#
# @example Validate against any supported type
#   validates :ref, sec_id: true
class SecIdValidator < ActiveModel::EachValidator
  # Built-in English default; `%{type_name}` is interpolated by ActiveModel/I18n (template
  # token syntax is required here, hence the cop disable).
  DEFAULT_MESSAGE = 'is not a valid %{type_name}' # rubocop:disable Style/FormatStringToken

  # Validates the validator's own options at class-load time (fail-fast on misconfiguration).
  #
  # @return [void]
  # @raise [ArgumentError] if both `type:` and `types:` are given, or a named type is unknown
  def check_validity!
    raise ArgumentError, 'Pass either :type or :types, not both' if options[:type] && options[:types]
    raise ArgumentError, ':types cannot be empty' if options[:types] && configured_types.empty?

    configured_types&.each { |type| SecID[type] }
  end

  # Validates `value` and, with `normalize: true`, rewrites it to canonical form on success.
  #
  # @param record [ActiveModel::Validations] the record being validated
  # @param attribute [Symbol] the attribute being validated
  # @param value [Object] the attribute value
  # @return [void]
  def validate_each(record, attribute, value)
    return if valid_value?(record, attribute, value)

    record.errors.add(
      attribute, :sec_id,
      message: options[:message] || detail_reason(value) || DEFAULT_MESSAGE,
      type_name: human_type_name
    )
  end

  private

  # Strict by default; with `normalize: true`, separator-lenient with canonical write-back on success.
  #
  # @param record [ActiveModel::Validations] the record being validated
  # @param attribute [Symbol] the attribute being validated
  # @param value [Object] the attribute value
  # @return [Boolean] whether the value is valid (and, in normalize mode, was rewritten)
  def valid_value?(record, attribute, value)
    return SecID.valid?(value, types: configured_types) unless options[:normalize]

    canonical = candidate_types.lazy.filter_map { |type| normalize_via(type, value) }.first
    return false unless canonical

    record.public_send("#{attribute}=", canonical)
    true
  end

  # @param type [Symbol] the identifier type to try
  # @param value [Object] the attribute value
  # @return [String, nil] the canonical form of `value` as `type`, or nil if it is not valid as `type`
  def normalize_via(type, value)
    SecID[type].normalize(value)
  rescue SecID::Error
    nil
  end

  # Concrete list of candidate types for the lenient path (never nil, unlike {#configured_types}).
  #
  # @return [Array<Symbol>]
  def candidate_types
    configured_types || SecID.identifiers.map { |klass| klass.short_name.downcase.to_sym }
  end

  # sec_id's specific failure reason, only when `details: true` and a single `type:` is set;
  # nil otherwise (allowlist/agnostic has no single type to attribute a reason to — R12).
  #
  # @param value [Object] the attribute value
  # @return [String, nil]
  def detail_reason(value)
    return unless options[:details] && options[:type]

    type = options[:type].to_sym
    return capture_reason(type, value) if options[:normalize]

    SecID[type].validate(value).errors.messages.first
  end

  # @param type [Symbol] the single configured identifier type
  # @param value [Object] the attribute value
  # @return [String, nil] the message of the SecID::Error raised when normalizing `value` as `type`
  def capture_reason(type, value)
    SecID[type].normalize(value)
    nil
  rescue SecID::Error => e
    e.message
  end

  # Configured types as symbols: `[type]` for a single type, the `types:` array for an allowlist,
  # or `nil` when type-agnostic (any supported type).
  #
  # @return [Array<Symbol>, nil]
  def configured_types
    return @configured_types if defined?(@configured_types)

    @configured_types =
      if options[:type] then [options[:type].to_sym]
      elsif options[:types] then Array(options[:types]).map(&:to_sym)
      end
  end

  # The type's short name for single-type mode, or a generic label for allowlist/agnostic mode.
  #
  # @return [String]
  def human_type_name
    options[:type] ? SecID[options[:type].to_sym].short_name : 'securities identifier'
  end
end
