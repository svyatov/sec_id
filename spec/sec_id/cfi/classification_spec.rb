# frozen_string_literal: true

RSpec.describe SecID::CFI::Classification do
  subject(:classification) { SecID::CFI.new(code).decode }

  describe 'a fully-specified equity (ESVUFR, AE4)' do
    let(:code) { 'ESVUFR' }

    it 'exposes the category as a field with code, name, and label' do
      expect(classification.category.code).to eq('E')
      expect(classification.category.name).to eq(:equity)
      expect(classification.category.label).to eq('Equities')
    end

    it 'exposes the group as a field with code, name, and label' do
      expect(classification.group.code).to eq('S')
      expect(classification.group.name).to eq(:common_shares)
      expect(classification.group.label).to eq('Common/Ordinary shares')
    end

    it 'answers scoped predicates on the category and group fields' do
      expect(classification.category.equity?).to be(true)
      expect(classification.group.common_shares?).to be(true)
    end

    it 'raises NoMethodError for a predicate outside the field domain' do
      expect { classification.category.voting? }.to raise_error(NoMethodError)
    end

    it 'exposes each attribute as a field keyed by its group meaning' do
      expect(classification.attributes.voting_right.name).to eq(:voting)
      expect(classification.attributes.payment_status.label).to eq('Fully paid')
      expect(classification.attributes.form.code).to eq('R')
    end

    it 'answers scoped predicates on attribute fields' do
      expect(classification.attributes.voting_right.voting?).to be(true)
      expect(classification.attributes.voting_right.non_voting?).to be(false)
      expect(classification.attributes.payment_status.fully_paid?).to be(true)
    end

    it 'renders a human-readable string from the labels' do
      expect(classification.to_s)
        .to eq('Equities / Common/Ordinary shares: Voting, Free of restrictions, Fully paid, Registered')
    end

    it 'is frozen, with frozen fields' do
      expect(classification).to be_frozen
      expect(classification.category).to be_frozen
    end
  end

  describe 'attributes as an enumerable collection' do
    subject(:attributes) { SecID::CFI.new('ESVUFR').decode.attributes }

    it 'iterates its fields in position order' do
      expect(attributes.map(&:meaning)).to eq(%i[voting_right ownership_restrictions payment_status form])
      expect(attributes.map(&:name)).to eq(%i[voting free_of_restrictions fully_paid registered])
    end

    it 'looks up a field by meaning with [], returning nil when absent' do
      expect(attributes[:form].name).to eq(:registered)
      expect(attributes[:nonexistent]).to be_nil
    end
  end

  describe 'meaning scoping (AE8)' do
    subject(:attributes) { SecID::CFI.new('EPVRFR').decode.attributes }

    it 'has no payment_status meaning on a preference share' do
      # EP position 5 (F) means fixed-rate income, not payment status.
      expect(attributes[:payment_status]).to be_nil
      expect { attributes.payment_status }.to raise_error(NoMethodError)
    end

    it 'decodes the income position and rejects out-of-domain predicates' do
      expect(attributes.income.fixed_rate?).to be(true)
      expect { attributes.income.fully_paid? }.to raise_error(NoMethodError)
    end
  end

  describe 'X and N/A handling' do
    it 'decodes X in a meaningful position to :not_applicable' do
      voting_right = SecID::CFI.new('ESXXXX').decode.attributes.voting_right
      expect(voting_right.name).to eq(:not_applicable)
      expect(voting_right.not_applicable?).to be(true)
      expect(voting_right.voting?).to be(false)
    end

    it 'omits pure-N/A positions from the attributes' do
      # FF position 6 is N/A and is absent from the decoded attributes.
      expect(SecID::CFI.new('FFSPSX').decode.attributes.map(&:meaning))
        .to eq(%i[underlying_assets delivery standardized])
    end

    it 'answers a value symbol shared across meanings on its own field' do
      # EYMMMM decodes every position to :others; the type field answers others?.
      expect(SecID::CFI.new('EYMMMM').decode.attributes.type.others?).to be(true)
    end

    it 'decodes a strategy code to empty attributes with category/group present' do
      classification = SecID::CFI.new('KRXXXX').decode
      expect(classification.attributes).to be_empty
      expect(classification.group.name).to eq(:rates)
      expect(classification.to_s).to eq('Strategies / Rates')
    end
  end

  describe '#to_h and #as_json' do
    it 'serializes category, group, and attributes as nested field hashes' do
      to_h = SecID::CFI.new('ESVUFR').decode.to_h
      expect(to_h[:category]).to eq(code: 'E', name: :equity, label: 'Equities')
      expect(to_h[:group]).to eq(code: 'S', name: :common_shares, label: 'Common/Ordinary shares')
      expect(to_h[:attributes][:voting_right]).to eq(code: 'V', name: :voting, label: 'Voting')
    end

    it 'serializes a strategy code with an empty attributes hash' do
      expect(SecID::CFI.new('KRXXXX').decode.to_h).to eq(
        category: { code: 'K', name: :strategies, label: 'Strategies' },
        group: { code: 'R', name: :rates, label: 'Rates' },
        attributes: {}
      )
    end

    it 'as_json delegates to to_h at every level, and a field stringifies to its label' do
      classification = SecID::CFI.new('ESVUFR').decode
      expect(classification.as_json).to eq(classification.to_h)
      expect(classification.category.as_json).to eq(classification.category.to_h)
      expect(classification.attributes.as_json).to eq(classification.attributes.to_h)
      expect(classification.category.to_s).to eq('Equities')
    end
  end
end
