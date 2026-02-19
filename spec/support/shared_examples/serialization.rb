# frozen_string_literal: true

# Shared examples for #to_h hash serialization across all identifier types.
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
end
