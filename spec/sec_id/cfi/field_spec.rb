# frozen_string_literal: true

RSpec.describe SecID::CFI::Field do
  subject(:field) do
    described_class.new('V', :voting, 'Voting', %i[voting non_voting not_applicable], meaning: :voting_right)
  end

  it 'exposes code, name, label, and meaning' do
    expect(field.code).to eq('V')
    expect(field.name).to eq(:voting)
    expect(field.label).to eq('Voting')
    expect(field.meaning).to eq(:voting_right)
  end

  it 'answers a predicate for each symbol in its domain' do
    expect(field.voting?).to be(true)
    expect(field.non_voting?).to be(false)
    expect(field.not_applicable?).to be(false)
  end

  it 'raises NoMethodError for a predicate outside its domain' do
    expect { field.equity? }.to raise_error(NoMethodError)
  end

  it 'defaults meaning to nil for category/group fields' do
    expect(described_class.new('E', :equity, 'Equities', %i[equity debt]).meaning).to be_nil
  end

  it 'stringifies to its label' do
    expect(field.to_s).to eq('Voting')
  end

  it 'serializes with to_h, and as_json delegates to to_h' do
    expect(field.to_h).to eq(code: 'V', name: :voting, label: 'Voting')
    expect(field.as_json).to eq(field.to_h)
  end

  it 'is frozen' do
    expect(field).to be_frozen
  end
end
