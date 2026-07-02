# frozen_string_literal: true

RSpec.describe SecID::CFI::Classification do
  subject(:classification) { SecID::CFI.new(code).decode }

  describe 'a fully-specified equity (ESVUFR, AE4)' do
    let(:code) { 'ESVUFR' }

    it 'wires the category and group fields from the tables' do
      expect(classification.category.name).to eq(:equity)
      expect(classification.category.label).to eq('Equities')
      expect(classification.group.name).to eq(:common_shares)
      expect(classification.group.label).to eq('Common/Ordinary shares')
    end

    it 'decodes each attribute into a field keyed by its group meaning' do
      expect(classification.attributes.map(&:meaning))
        .to eq(%i[voting_right ownership_restrictions payment_status form])
      expect(classification.attributes.map(&:name))
        .to eq(%i[voting free_of_restrictions fully_paid registered])
    end

    it 'renders a human-readable string from the labels' do
      expect(classification.to_s)
        .to eq('Equities / Common/Ordinary shares: Voting, Free of restrictions, Fully paid, Registered')
    end

    it 'serializes to nested field hashes' do
      to_h = classification.to_h
      expect(to_h[:category]).to eq(code: 'E', name: :equity, label: 'Equities')
      expect(to_h[:attributes][:voting_right]).to eq(code: 'V', name: :voting, label: 'Voting')
      expect(classification.as_json).to eq(to_h)
    end

    it 'is frozen' do
      expect(classification).to be_frozen
    end
  end

  describe 'meaning composition (AE8)' do
    it 'includes only the meanings the group defines' do
      # EP position 5 (F) is fixed-rate income, so there is no payment_status meaning.
      attributes = SecID::CFI.new('EPVRFR').decode.attributes
      expect(attributes[:payment_status]).to be_nil
      expect(attributes.income.name).to eq(:fixed_rate)
    end
  end

  describe 'X and N/A handling' do
    it 'decodes X in a meaningful position to :not_applicable' do
      expect(SecID::CFI.new('ESXXXX').decode.attributes.voting_right.name).to eq(:not_applicable)
    end

    it 'renders every meaningful X position as Not applicable in to_s' do
      expect(SecID::CFI.new('ESXXXX').decode.to_s)
        .to eq('Equities / Common/Ordinary shares: Not applicable, Not applicable, Not applicable, Not applicable')
    end

    it 'omits pure-N/A positions from the attributes' do
      # FF position 6 is N/A and is absent from the decoded attributes.
      expect(SecID::CFI.new('FFSPSX').decode.attributes.map(&:meaning))
        .to eq(%i[underlying_assets delivery standardized])
    end

    it 'decodes a strategy code to empty attributes with category/group present' do
      classification = SecID::CFI.new('KRXXXX').decode
      expect(classification.attributes).to be_empty
      expect(classification.group.name).to eq(:rates)
      expect(classification.to_s).to eq('Strategies / Rates')
    end

    it 'serializes a strategy code with an empty attributes hash' do
      expect(SecID::CFI.new('KRXXXX').decode.to_h).to eq(
        category: { code: 'K', name: :strategies, label: 'Strategies' },
        group: { code: 'R', name: :rates, label: 'Rates' },
        attributes: {}
      )
    end
  end
end
