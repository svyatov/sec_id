# frozen_string_literal: true

RSpec.describe SecID::CFI::Classification do
  subject(:classification) { SecID::CFI.new(code).decode }

  describe 'a fully-specified equity (ESVUFR, AE4)' do
    let(:code) { 'ESVUFR' }

    it 'decodes the category and group with labels' do
      expect(classification.category).to eq(:equity)
      expect(classification.category_label).to eq('Equities')
      expect(classification.group).to eq(:common_shares)
      expect(classification.group_label).to eq('Common/Ordinary shares')
    end

    it 'decodes the four attributes keyed by their group meaning' do
      expect(classification.attributes).to eq(
        voting_right: :voting, ownership_restrictions: :free_of_restrictions,
        payment_status: :fully_paid, form: :registered
      )
    end

    it 'exposes the ISO labels for each attribute value' do
      expect(classification.attribute_labels).to eq(
        voting_right: 'Voting', ownership_restrictions: 'Free of restrictions',
        payment_status: 'Fully paid', form: 'Registered'
      )
    end

    it 'answers table-derived predicates' do
      expect(classification.voting?).to be(true)
      expect(classification.fully_paid?).to be(true)
      expect(classification.registered?).to be(true)
    end

    it 'renders a human-readable string from the labels' do
      expect(classification.to_s)
        .to eq('Equities / Common/Ordinary shares: Voting, Free of restrictions, Fully paid, Registered')
    end

    it 'is frozen' do
      expect(classification).to be_frozen
    end
  end

  describe 'value-level predicate semantics (AE8)' do
    it 'is false when the value is absent (fully_paid? on a preference share)' do
      # EP position 5 (F) means fixed-rate income, not payment status.
      expect(SecID::CFI.new('EPVRFR').decode.fully_paid?).to be(false)
    end

    it 'is true when a share is actually fully paid' do
      expect(SecID::CFI.new('ESVUFR').decode.fully_paid?).to be(true)
    end

    it 'returns false for a value not present anywhere in the code' do
      expect(SecID::CFI.new('ESVUFR').decode.bearer?).to be(false) # form is registered, not bearer
    end

    it 'answers true when a symbol shared across meanings matches any position' do
      # EYMMMM decodes every position to :others (a symbol used under several meanings).
      expect(SecID::CFI.new('EYMMMM').decode.others?).to be(true)
    end
  end

  describe 'X and N/A handling' do
    it 'decodes X in a meaningful position to :not_applicable' do
      expect(SecID::CFI.new('ESXXXX').decode.attributes).to eq(
        voting_right: :not_applicable, ownership_restrictions: :not_applicable,
        payment_status: :not_applicable, form: :not_applicable
      )
    end

    it 'omits pure-N/A positions from the attributes hash' do
      # FF position 6 is N/A and is absent from the decoded attributes.
      expect(SecID::CFI.new('FFSPSX').decode.attributes.keys).to eq(%i[underlying_assets delivery standardized])
    end

    it 'decodes a strategy code to an empty attributes hash with category/group present' do
      classification = SecID::CFI.new('KRXXXX').decode
      expect(classification.attributes).to be_empty
      expect(classification.group).to eq(:rates)
      expect(classification.group_label).to eq('Rates')
      expect(classification.to_s).to eq('Strategies / Rates')
    end
  end

  describe '#to_h and #as_json' do
    it 'returns the populated classification keyed by field' do
      expect(SecID::CFI.new('ESVUFR').decode.to_h).to include(
        category: :equity, category_label: 'Equities', group: :common_shares,
        attributes: { voting_right: :voting, ownership_restrictions: :free_of_restrictions,
                      payment_status: :fully_paid, form: :registered }
      )
    end

    it 'returns the complete key set with empty attributes for a strategy code' do
      expect(SecID::CFI.new('KRXXXX').decode.to_h).to eq(
        category: :strategies, category_label: 'Strategies',
        group: :rates, group_label: 'Rates', attributes: {}, attribute_labels: {}
      )
    end

    it 'as_json delegates to to_h' do
      classification = SecID::CFI.new('ESVUFR').decode
      expect(classification.as_json).to eq(classification.to_h)
    end
  end
end
