# frozen_string_literal: true

RSpec.describe SecID::CFI::Tables do
  # Expected group count per category, from docs/research/iso-10962-2021-cfi-tables.md §3.
  let(:group_counts) do
    { 'E' => 8, 'C' => 8, 'D' => 12, 'R' => 7, 'O' => 3, 'F' => 2, 'S' => 6,
      'H' => 6, 'I' => 2, 'J' => 5, 'K' => 7, 'L' => 3, 'T' => 7, 'M' => 2 }
  end

  describe 'structure integrity' do
    it 'defines exactly 14 categories' do
      expect(described_class::CATEGORIES.size).to eq(14)
    end

    it 'defines exactly 78 groups' do
      total = described_class::GROUPS.each_value.sum(&:size)
      expect(total).to eq(78)
    end

    it 'matches the per-category group counts from the research doc' do
      actual = described_class::GROUPS.transform_values(&:size)
      expect(actual).to eq(group_counts)
    end

    it 'has a category entry for every group category and vice versa' do
      expect(described_class::GROUPS.keys).to match_array(described_class::CATEGORIES.keys)
    end

    it 'gives every category a symbol and a non-empty label' do
      bad = described_class::CATEGORIES.reject { |_, (symbol, label)| symbol.is_a?(Symbol) && present_string?(label) }
      expect(bad).to be_empty
    end

    it 'gives every group a symbol, a label, and exactly 4 position entries' do
      bad = groups.reject do |group|
        group[:symbol].is_a?(Symbol) && present_string?(group[:label]) && group[:attributes].size == 4
      end
      expect(bad).to be_empty
    end

    it 'makes every position an N/A marker or a non-empty letter map' do
      expect(positions.reject { |position| na_or_valid_map?(position) }).to be_empty
    end

    it 'never lists X in a value map (X is universal and implicit)' do
      expect(positions.select { |position| position&.last&.key?('X') }).to be_empty
    end

    it 'gives every group distinct position meanings (AttributeSet keys by meaning)' do
      bad = groups.reject do |group|
        meanings = group[:attributes].filter_map { |position| position&.first }
        meanings.uniq.size == meanings.size
      end
      expect(bad).to be_empty
    end
  end

  describe 'immutability' do
    it 'deeply freezes the top-level structures' do
      expect(described_class::CATEGORIES).to be_frozen
      expect(described_class::GROUPS).to be_frozen
      expect(described_class::ED_REDEMPTION_RULE).to be_frozen
    end

    it 'deeply freezes every group and non-N/A position' do
      unfrozen = groups.reject(&:frozen?) +
                 positions.compact.reject { |position| position.frozen? && position.last.frozen? }
      expect(unfrozen).to be_empty
    end
  end

  describe 'spot checks against the research doc' do
    it 'maps ES voting position: V -> voting' do
      voting = described_class::GROUPS.dig('E', 'S', :attributes)[0]
      expect(voting.first).to eq(:voting_right)
      expect(voting.last['V']).to eq([:voting, 'Voting'])
    end

    it 'classifies H groups by underlying (R/T/E/C/F/M), not call/put' do
      expect(described_class::GROUPS['H'].keys).to match_array(%w[R T E C F M])
      expect(described_class::GROUPS.dig('H', 'R', :symbol)).to eq(:rates)
    end

    it 'shares the H option-style block across all H groups' do
      styles = described_class::GROUPS['H'].values.map { |g| g[:attributes][1].last }
      expect(styles.uniq.size).to eq(1)
      expect(styles.first['A']).to eq([:european_call, 'European call'])
    end

    it 'makes all K groups pure N/A across positions 3-6' do
      k_attributes = described_class::GROUPS['K'].each_value.map { |group| group[:attributes] }
      expect(k_attributes).to all(eq([nil, nil, nil, nil]))
    end

    it 'gives DD no Form position (displaced by the extra dependency attribute)' do
      meanings = described_class::GROUPS.dig('D', 'D', :attributes).map { |p| p&.first }
      expect(meanings).to eq(%i[underlying interest_type guarantee redemption])
    end

    it 'restricts the ED redemption position to N/X for common-share/LP underlyings' do
      rule = described_class::ED_REDEMPTION_RULE
      expect(rule).to include(category: 'E', group: 'D', restricted_underlyings: %w[S L], allowed_redemptions: %w[N X])
    end
  end

  describe 'corrected group tables (no phantom groups)' do
    it 'has no M group in F, I, J, or L' do
      with_m = %w[F I J L].select { |category| described_class::GROUPS[category].key?('M') }
      expect(with_m).to be_empty
    end

    it 'corrects the D structured-product and MBS/ABS/municipal letters' do
      symbols = %w[E G A N].to_h { |letter| [letter, described_class::GROUPS.dig('D', letter, :symbol)] }
      expect(symbols).to eq('E' => :structured_products_without_protection, 'G' => :mortgage_backed_securities,
                            'A' => :asset_backed_securities, 'N' => :municipal_bonds)
    end

    it 'corrects the L, T, and M group letters' do
      expect(described_class::GROUPS.dig('L', 'L', :symbol)).to eq(:loan_lease)
      expect(described_class::GROUPS.dig('L', 'S', :symbol)).to eq(:securities_lending)
      expect(described_class::GROUPS.dig('T', 'C', :symbol)).to eq(:currencies)
      expect(described_class::GROUPS.dig('T', 'I', :symbol)).to eq(:indices)
      expect(described_class::GROUPS.dig('M', 'M', :symbol)).to eq(:other_assets)
    end
  end

  describe '.group' do
    it 'returns the group definition for a known category/group' do
      expect(described_class.group('E', 'S')[:symbol]).to eq(:common_shares)
    end

    it 'returns nil for an unknown group' do
      expect(described_class.group('E', 'Z')).to be_nil
    end
  end

  describe '.ed_rule_applies?' do
    it 'is true for an ED code with a restricted underlying (S or L)' do
      expect(described_class.ed_rule_applies?('E', 'D', %w[S B F B])).to be(true)
      expect(described_class.ed_rule_applies?('E', 'D', %w[L B F B])).to be(true)
    end

    it 'is false for an ED code with a non-restricted underlying' do
      expect(described_class.ed_rule_applies?('E', 'D', %w[B B F B])).to be(false)
    end

    it 'is false for a non-ED group' do
      expect(described_class.ed_rule_applies?('E', 'S', %w[S B F B])).to be(false)
    end
  end

  def groups
    described_class::GROUPS.each_value.flat_map(&:values)
  end

  def positions
    groups.flat_map { |group| group[:attributes] }
  end

  def present_string?(value)
    value.is_a?(String) && !value.empty?
  end

  def na_or_valid_map?(position)
    return true if position.nil?

    meaning, values = position
    meaning.is_a?(Symbol) && values.is_a?(Hash) && !values.empty? && values.all? { |cell| valid_cell?(*cell) }
  end

  def valid_cell?(letter, (symbol, label))
    letter.match?(/\A[A-Z]\z/) && symbol.is_a?(Symbol) && present_string?(label)
  end
end
