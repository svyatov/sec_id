# frozen_string_literal: true

RSpec.describe SecID::CFI::AttributeSet do
  subject(:set) { described_class.new([voting, form]) }

  let(:voting) { SecID::CFI::Field.new('V', :voting, 'Voting', %i[voting non_voting], meaning: :voting_right) }
  let(:form) { SecID::CFI::Field.new('R', :registered, 'Registered', %i[registered bearer], meaning: :form) }

  it 'is enumerable over its fields in order' do
    expect(set.map(&:meaning)).to eq(%i[voting_right form])
    expect(set.to_a).to eq([voting, form])
  end

  it 'reads a present field by its meaning name' do
    expect(set.voting_right).to eq(voting)
  end

  it 'raises NoMethodError for an absent meaning' do
    expect { set.payment_status }.to raise_error(NoMethodError)
  end

  it 'looks up by meaning with [], returning nil when absent' do
    expect(set[:form]).to eq(form)
    expect(set[:payment_status]).to be_nil
  end

  it 'reports empty? and serializes to nested field hashes' do
    expect(described_class.new([]).empty?).to be(true)
    expect(set.to_h).to eq(voting_right: voting.to_h, form: form.to_h)
    expect(set.as_json).to eq(set.to_h)
  end

  it 'is frozen' do
    expect(set).to be_frozen
  end
end
