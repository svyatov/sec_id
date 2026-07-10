# frozen_string_literal: true

# Shared examples for #to_h serialization and #deconstruct_keys destructuring
# across all identifier types. Both read the same components hash.
#
# @param valid_id [String] a valid identifier
# @param invalid_id [String] an invalid identifier
# @param expected_type [Symbol] the expected :type value (e.g. :isin)
# @param expected_components [Hash] the expected :components hash for valid_id
RSpec.shared_examples 'a hashable identifier' do |params|
  let(:identifier_class) { described_class }
  let(:valid_id) { params[:valid_id] }
  let(:invalid_id) { params[:invalid_id] }
  let(:expected_type) { params[:expected_type] }
  let(:expected_components) { params[:expected_components] }

  describe '#to_h' do
    context 'when valid' do
      subject(:hash) { identifier_class.new(valid_id).to_h }

      it 'returns a Hash with all expected keys' do
        expect(hash).to be_a(Hash)
        expect(hash.keys).to eq(%i[type full_id normalized valid components])
      end

      it 'has correct type' do
        expect(hash[:type]).to eq(expected_type)
      end

      it 'has type resolvable via SecID[]' do
        expect(SecID[hash[:type]]).to eq(identifier_class)
      end

      it 'has valid: true' do
        expect(hash[:valid]).to be(true)
      end

      it 'has normalized as a String' do
        expect(hash[:normalized]).to be_a(String)
      end

      it 'has matching components' do
        expect(hash[:components]).to eq(expected_components)
      end

      it 'is JSON-serializable' do
        require 'json'
        expect { JSON.generate(hash) }.not_to raise_error
      end
    end

    context 'when invalid' do
      subject(:hash) { identifier_class.new(invalid_id).to_h }

      it 'has valid: false' do
        expect(hash[:valid]).to be(false)
      end

      it 'has normalized: nil' do
        expect(hash[:normalized]).to be_nil
      end

      it 'has type' do
        expect(hash[:type]).to eq(expected_type)
      end
    end
  end

  describe '#deconstruct_keys' do
    subject(:identifier) { identifier_class.new(valid_id) }

    # Both public readers of `components` are pinned to the same independent literal, which is
    # what proves they cannot drift. Comparing the two readers to each other would be x == x --
    # `deconstruct_keys` and `to_h` both call `components`, so it would pass however badly it broke.
    it 'returns the components hash, equal to to_h[:components]' do
      expect(identifier.deconstruct_keys(nil)).to eq(expected_components)
      expect(identifier.to_h[:components]).to eq(expected_components)
    end

    it 'matches a bare constant pattern' do
      expect((identifier in ^(identifier_class))).to be(true)
    end

    it 'matches a hash pattern binding its components' do
      identifier => { **bound }
      expect(bound).to eq(expected_components)
    end

    # AE5: CIK, WKN and Valoren have no sub-fields, so no keyed pattern can match them.
    if params[:expected_components].empty?
      it 'matches no keyed pattern' do
        expect((identifier in { identifier: _ })).to be(false)
      end
    end
  end
end
