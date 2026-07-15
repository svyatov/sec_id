# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecID::Suggestion do
  let(:isin) { SecID::ISIN.new('US5949181045') }
  let(:suggestion) do
    described_class.new(
      type: :isin, identifier: isin, edit: :substitution,
      position: 9, from: 'O', to: '0', confidence: :high
    )
  end

  describe 'construction and readers' do
    it 'exposes each field via keyword construction' do
      expect(suggestion).to have_attributes(
        type: :isin, identifier: isin, edit: :substitution,
        position: 9, from: 'O', to: '0', confidence: :high
      )
    end

    it 'is frozen and immutable' do
      expect(suggestion.frozen?).to be(true)
    end
  end

  describe 'value equality' do
    it 'compares equal and shares a hash for identical fields' do
      twin = suggestion.with
      expect(suggestion).to eq(twin)
      expect(suggestion.hash).to eq(twin.hash)
    end

    it 'is usable as a Hash key' do
      expect({ suggestion => :found }[suggestion.with]).to eq(:found)
    end

    it 'differs when any field differs' do
      expect(suggestion).not_to eq(suggestion.with(confidence: :medium))
    end
  end

  describe '#to_h and #as_json' do
    it 'returns the symbol-keyed field hash' do
      expect(suggestion.to_h).to eq(
        type: :isin, identifier: isin, edit: :substitution,
        position: 9, from: 'O', to: '0', confidence: :high
      )
    end

    it 'serializes as_json identically to to_h' do
      expect(suggestion.as_json).to eq(suggestion.to_h)
    end
  end

  describe '#to_s' do
    it 'returns the corrected identifier string' do
      expect(suggestion.to_s).to eq('US5949181045')
    end
  end

  describe 'domain enumerations' do
    it 'lists every edit kind the engine produces in EDIT_KINDS' do
      produced = SecID::ISIN.suggest('US5499181045').map(&:edit).uniq
      expect(produced - described_class::EDIT_KINDS).to be_empty
      expect(described_class::EDIT_KINDS).to eq(%i[substitution transposition checksum])
    end

    it 'lists every non-nil confidence the engine produces in CONFIDENCE_LEVELS' do
      produced = SecID::ISIN.suggest('US5499181045').map(&:confidence).compact.uniq
      expect(produced - described_class::CONFIDENCE_LEVELS).to be_empty
      expect(described_class::CONFIDENCE_LEVELS).to eq(%i[high medium])
    end
  end

  describe 'edit-kind coordinate systems' do
    it 'encodes a transposition as left index plus the swapped two-char substring' do
      transposition = suggestion.with(edit: :transposition, position: 4, from: 'AB', to: 'BA', confidence: :medium)
      expect(transposition).to have_attributes(edit: :transposition, position: 4, from: 'AB', to: 'BA')
    end

    it 'encodes a checksum recompute with a nil position and confidence' do
      checksum = suggestion.with(edit: :checksum, position: nil, from: '0', to: '5', confidence: nil)
      expect(checksum).to have_attributes(edit: :checksum, position: nil, confidence: nil)
    end
  end
end
