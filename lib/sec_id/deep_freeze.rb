# frozen_string_literal: true

module SecID
  # Recursively freezes a nested structure of Hashes and Arrays and returns it.
  # Used to make the CFI reference tables and their derived lookups deeply
  # immutable in one call instead of freezing each level by hand.
  module DeepFreeze
    # @param object [Object] the (possibly nested) Hash/Array structure to freeze
    # @return [Object] the same object, deeply frozen
    def self.call(object)
      case object
      when Hash then object.each_value { |value| call(value) }
      when Array then object.each { |value| call(value) }
      end
      object.freeze
    end
  end
end
