# frozen_string_literal: true

RSpec.describe SecID::CFI do
  let(:cfi) { described_class.new(cfi_code) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

  # Metadata
  it_behaves_like 'an identifier with metadata',
                  full_name: 'Classification of Financial Instruments',
                  id_length: 6,
                  has_checksum: false

  it_behaves_like 'a generatable identifier'

  it_behaves_like 'a normalizable identifier',
                  valid_id: 'ESVUFR',
                  dirty_id: 'esvufr',
                  invalid_id: 'INVALID'

  it_behaves_like 'a formattable identifier',
                  valid_id: 'ESVUFR',
                  dirty_id: 'esvufr',
                  invalid_id: 'INVALID'

  # Validation API
  it_behaves_like 'a validatable identifier',
                  valid_id: 'ESXXXX',
                  invalid_length_id: 'ES',
                  invalid_chars_id: 'ES1234'

  it_behaves_like 'a validate! identifier',
                  valid_id: 'ESXXXX',
                  invalid_length_id: 'ES',
                  invalid_chars_id: 'ES1234'

  # Serialization
  it_behaves_like 'a hashable identifier',
                  valid_id: 'ESVUFR',
                  invalid_id: 'INVALID',
                  expected_type: :cfi,
                  expected_components: {
                    category_code: 'E', group_code: 'S', attr1: 'V', attr2: 'U', attr3: 'F', attr4: 'R'
                  }

  describe 'valid CFI parsing' do
    context 'when CFI is mixed case' do
      let(:cfi_code) { 'EsXxXx' }

      it 'normalizes to uppercase' do
        expect(cfi.identifier).to eq('ESXXXX')
        expect(cfi.category_code).to eq('E')
        expect(cfi.group_code).to eq('S')
        expect(cfi.attr1).to eq('X')
      end
    end

    context 'when CFI is minimal equity (ESXXXX)' do
      let(:cfi_code) { 'ESXXXX' }

      it 'parses identifier correctly' do
        expect(cfi.identifier).to eq('ESXXXX')
      end

      it 'parses category and group codes' do
        expect(cfi.category_code).to eq('E')
        expect(cfi.group_code).to eq('S')
      end

      it 'parses attribute codes' do
        expect(cfi.attr1).to eq('X')
        expect(cfi.attr2).to eq('X')
        expect(cfi.attr3).to eq('X')
        expect(cfi.attr4).to eq('X')
      end

      it 'returns semantic category and group' do
        expect(cfi.category).to eq(:equity)
        expect(cfi.group).to eq(:common_shares)
      end
    end

    context 'when CFI has full equity attributes (ESVUFR)' do
      let(:cfi_code) { 'ESVUFR' }

      it 'parses identifier correctly' do
        expect(cfi.identifier).to eq('ESVUFR')
      end

      it 'parses category and group codes' do
        expect(cfi.category_code).to eq('E')
        expect(cfi.group_code).to eq('S')
      end

      it 'parses attribute codes' do
        expect(cfi.attr1).to eq('V')
        expect(cfi.attr2).to eq('U')
        expect(cfi.attr3).to eq('F')
        expect(cfi.attr4).to eq('R')
      end

      it 'returns semantic category and group' do
        expect(cfi.category).to eq(:equity)
        expect(cfi.group).to eq(:common_shares)
      end
    end

    context 'when CFI is debt instrument (DBXXXX)' do
      let(:cfi_code) { 'DBXXXX' }

      it 'parses category and group codes' do
        expect(cfi.identifier).to eq('DBXXXX')
        expect(cfi.category_code).to eq('D')
        expect(cfi.group_code).to eq('B')
      end

      it 'returns semantic category and group' do
        expect(cfi.category).to eq(:debt_instruments)
        expect(cfi.group).to eq(:bonds)
      end
    end

    context 'when CFI is lowercase' do
      let(:cfi_code) { 'esxxxx' }

      it 'normalizes to uppercase' do
        expect(cfi.identifier).to eq('ESXXXX')
        expect(cfi.category_code).to eq('E')
      end
    end
  end

  describe 'category and group accessors' do
    # Test a representative sample of categories
    {
      'ESXXXX' => { category: :equity, group: :common_shares },
      'EPXXXX' => { category: :equity, group: :preferred_shares },
      'CIXXXX' => { category: :collective_investment_vehicles, group: :standard_investment_funds },
      'DBXXXX' => { category: :debt_instruments, group: :bonds },
      'RAXXXX' => { category: :entitlements, group: :allotment_rights },
      'OCXXXX' => { category: :listed_options, group: :call_options },
      'FFXXXX' => { category: :futures, group: :financial_futures },
      'SRXXXX' => { category: :swaps, group: :rates },
      'HCXXXX' => { category: :non_listed_options, group: :credit },
      'IFXXXX' => { category: :spot, group: :foreign_exchange },
      'JFXXXX' => { category: :forwards, group: :foreign_exchange },
      'KRXXXX' => { category: :strategies, group: :rates },
      'LLXXXX' => { category: :financing, group: :loan_lease },
      'LSXXXX' => { category: :financing, group: :securities_lending },
      'TCXXXX' => { category: :referential_instruments, group: :currencies },
      'TIXXXX' => { category: :referential_instruments, group: :indices },
      'MCXXXX' => { category: :miscellaneous, group: :combined_instruments }
    }.each do |code, expected|
      it "returns #{expected[:category]}/#{expected[:group]} for #{code}" do
        cfi = described_class.new(code)
        expect(cfi.category).to eq(expected[:category])
        expect(cfi.group).to eq(expected[:group])
      end
    end
  end

  describe 'ISO 10962:2021 corrected group tables' do
    it 'classifies H (non-listed options) by underlying, not call/put' do
      expect(described_class.groups_for('H')).to eq(
        'R' => :rates, 'T' => :commodities, 'E' => :equity,
        'C' => :credit, 'F' => :foreign_exchange, 'M' => :miscellaneous
      )
    end

    it 'corrects the L, T, D, and M group symbols' do
      expect(described_class.groups_for('L')).to include('L' => :loan_lease, 'S' => :securities_lending)
      expect(described_class.groups_for('T')).to include('C' => :currencies, 'T' => :commodities, 'I' => :indices)
      expect(described_class.groups_for('D')).to include('E' => :structured_products_without_protection,
                                                         'N' => :municipal_bonds)
      expect(described_class.groups_for('M')).to include('M' => :other_assets)
    end

    it 'drops the invented municipal_notes group' do
      expect(described_class.groups_for('D').values).not_to include(:municipal_notes)
    end

    it 'rejects the phantom FM/IM/JM/LM groups with :invalid_group' do
      %w[FMXXXX IMXXXX JMXXXX LMXXXX].each do |code|
        result = described_class.new(code).errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_group]), "expected #{code} invalid group"
      end
    end

    it 'keeps the 14-letter category set unchanged' do
      expect(described_class.categories.size).to eq(14)
      expect(described_class.categories['E']).to eq(:equity)
    end
  end

  describe 'ISO 10962:2021 strict attribute validation' do
    it 'accepts a non-listed option on rates (AE1)' do
      expect(described_class.valid?('HRXXXX')).to be(true)
    end

    it 'rejects impermissible equity attribute letters (AE2)' do
      expect(described_class.valid?('ESZZZZ')).to be(false)
    end

    it 'requires XXXX for strategy codes (AE3)' do
      expect(described_class.valid?('KRXXXX')).to be(true)
      expect(described_class.valid?('KRAAAA')).to be(false)
    end

    it 'validates derivative categories as strictly as the rest (AE6)' do
      expect(described_class.valid?('SRQQQQ')).to be(false)
    end

    it 'enforces the ED cross-position rule (AE7)' do
      expect(described_class.valid?('EDSBFB')).to be(false)
      expect(described_class.valid?('EDSNFB')).to be(true)
    end

    it 'accepts X in any meaningful position' do
      expect(described_class.valid?('ESXXXX')).to be(true)
    end

    it 'accepts only X in a pure-N/A position' do
      expect(described_class.valid?('FFSPSX')).to be(true)
      expect(described_class.valid?('FFSPSA')).to be(false)
    end

    it 'keeps existing valid equity fixtures valid' do
      %w[ESVUFR ESNTOB ESRXXX ESEXXX ESXXPX].each do |code|
        expect(described_class.valid?(code)).to be(true), "expected #{code} valid"
      end
    end
  end

  describe 'attribute error surface' do
    it 'reports :invalid_attribute with the offending positions and group' do
      result = described_class.new('ESZZZZ').errors
      expect(result.details.map { |d| d[:error] }).to eq([:invalid_attribute])
      expect(result.details.first[:message])
        .to eq("Invalid attribute(s) for group 'ES': position 3 'Z', position 4 'Z', position 5 'Z', position 6 'Z'")
    end

    it 'phrases the strategy violation as requiring XXXX' do
      expect(described_class.new('KRAAAA').errors.details.first[:message])
        .to eq('Strategies require XXXX in positions 3-6')
    end

    it 'names the redemption position for an ED rule violation' do
      expect(described_class.new('EDSBFB').errors.details.first[:message])
        .to eq("Invalid attribute(s) for group 'ED': position 4 'B'")
    end

    it 'lists a position once when both the matrix and the ED rule flag it' do
      expect(described_class.new('EDSZFB').errors.details.first[:message])
        .to eq("Invalid attribute(s) for group 'ED': position 4 'Z'")
    end

    it 'raises InvalidStructureError from validate! for a bad attribute' do
      expect { described_class.new('ESZZZZ').validate! }
        .to raise_error(SecID::InvalidStructureError, /Invalid attribute/)
    end

    it 'does not report attribute errors when the group is already invalid' do
      expect(described_class.new('EZXXXX').errors.details.map { |d| d[:error] }).to eq([:invalid_group])
    end

    it 'is surfaced by SecID.explain' do
      cfi_result = SecID.explain('ESZZZZ')[:candidates].find { |c| c[:type] == :cfi }
      expect(cfi_result[:valid]).to be(false)
      expect(cfi_result[:errors]).to include(a_hash_including(error: :invalid_attribute))
    end
  end

  describe 'generation honors the attribute tables' do
    it 'generates only valid codes across many seeds' do
      invalid = (0...500).map { |s| described_class.generate(random: Random.new(s)) }.reject(&:valid?)
      expect(invalid).to be_empty
    end

    it 'ends every strategy code in XXXX' do
      strategies = (0...2000).map { |s| described_class.generate(random: Random.new(s)).identifier }
                             .select { |id| id.start_with?('K') }
      expect(strategies).to all(end_with('XXXX'))
    end

    it 'honors the ED conditional for a seed that lands on it' do
      cfi = described_class.generate(random: Random.new(360))
      expect(cfi.identifier).to start_with('EDL')
      expect(cfi.attr2).to eq('N') # redemption restricted to N/X for LP-unit underlying
      expect(cfi).to be_valid
    end
  end

  describe 'detection fallout from strict validation' do
    it 'no longer extracts RANDOM (invalid RA attributes)' do
      expect(SecID.extract('The word RANDOM here')).to eq([])
    end

    it 'still detects ESVUFR as WKN and CFI' do
      expect(SecID.detect('ESVUFR')).to eq(%i[wkn cfi])
    end
  end

  describe '#decode' do
    it 'returns a Classification for a valid CFI' do
      expect(described_class.new('ESVUFR').decode).to be_a(SecID::CFI::Classification)
    end

    it 'returns nil for an invalid CFI (AE5)' do
      expect(described_class.new('QQXXXX').decode).to be_nil
    end

    it 'returns nil for an unparsed/garbage instance without raising' do
      expect(described_class.new('INVALID').decode).to be_nil
    end

    it 'no longer responds to the removed equity predicates' do
      cfi = described_class.new('ESVUFR')
      %i[equity? voting? non_voting? restricted_voting? enhanced_voting? restrictions?
         no_restrictions? fully_paid? nil_paid? partly_paid? bearer? registered?].each do |predicate|
        expect(cfi).not_to respond_to(predicate)
      end
    end
  end

  describe '.valid?' do
    context 'when CFI is valid' do
      it 'returns true for various valid CFI codes' do
        %w[
          ESXXXX ESVUFR EPXXXX DBXXXX CIXXXX RAXXXX
          OCXXXX FFXXXX SRXXXX HCXXXX IFXXXX JFXXXX
          KRXXXX LSXXXX TIXXXX MCXXXX MMXXXX
        ].each do |code|
          expect(described_class.valid?(code)).to be(true), "Expected #{code} to be valid"
        end
      end
    end

    context 'when CFI is invalid' do
      it 'returns false for wrong length' do
        expect(described_class.valid?('ESXXX')).to be(false)
        expect(described_class.valid?('ESXXXXX')).to be(false)
      end

      it 'returns false for digits' do
        expect(described_class.valid?('ES1234')).to be(false)
        expect(described_class.valid?('E1XXXX')).to be(false)
      end

      it 'returns false for invalid category code' do
        expect(described_class.valid?('QSXXXX')).to be(false)
        expect(described_class.valid?('ASXXXX')).to be(false)
        expect(described_class.valid?('ZSXXXX')).to be(false)
      end

      it 'returns false for invalid group code for category' do
        expect(described_class.valid?('EZXXXX')).to be(false)
        expect(described_class.valid?('EAXXXX')).to be(false)
        expect(described_class.valid?('DQXXXX')).to be(false)
      end

      it 'returns false for invalid characters' do
        expect(described_class.valid?('ES-XXX')).to be(false)
        expect(described_class.valid?('ES XX X')).to be(false)
      end
    end
  end

  describe '#errors' do
    context 'when category is invalid' do
      it 'returns :invalid_category error with descriptive message' do
        result = described_class.new('ZSXXXX').errors
        expect(result.details.map { |d| d[:error] }).to include(:invalid_category)
        expect(result.details.first[:message]).to match(/category/i)
      end
    end

    context 'when group is invalid for category' do
      it 'returns :invalid_group error with descriptive message' do
        result = described_class.new('EZXXXX').errors
        expect(result.details.map { |d| d[:error] }).to eq([:invalid_group])
        expect(result.details.first[:message]).to match(/Group/i)
      end
    end

    context 'when both category and group are invalid' do
      it 'returns both errors with messages' do
        result = described_class.new('QZXXXX').errors
        expect(result.details.map { |d| d[:error] }).to eq(%i[invalid_category invalid_group])
        expect(result.messages.size).to eq(2)
        expect(result.size).to eq(2)
      end
    end
  end

  describe '#validate!' do
    context 'when category is invalid' do
      it 'raises InvalidStructureError' do
        expect { described_class.new('ZSXXXX').validate! }
          .to raise_error(SecID::InvalidStructureError, /category/i)
      end
    end

    context 'when group is invalid' do
      it 'raises InvalidStructureError' do
        expect { described_class.new('EZXXXX').validate! }
          .to raise_error(SecID::InvalidStructureError, /Group/i)
      end
    end
  end

  describe '.categories' do
    it 'returns the CATEGORIES hash' do
      expect(described_class.categories).to eq(SecID::CFI::CATEGORIES)
    end

    it 'includes all 14 category codes' do
      expect(described_class.categories.size).to eq(14)
    end
  end

  describe '.groups_for' do
    it 'returns equity groups for E' do
      result = described_class.groups_for('E')
      expect(result).to be_a(Hash)
      expect(result['S']).to eq(:common_shares)
    end

    it 'returns nil for unknown category' do
      expect(described_class.groups_for('Z')).to be_nil
    end

    it 'is case-insensitive' do
      expect(described_class.groups_for('e')).to eq(described_class.groups_for('E'))
    end
  end

  describe '#to_s' do
    let(:cfi_code) { 'ESVUFR' }

    it 'returns the identifier' do
      expect(cfi.to_s).to eq('ESVUFR')
    end
  end

  describe '#full_id' do
    let(:cfi_code) { 'esvufr' }

    it 'returns the normalized (uppercased) full id' do
      expect(cfi.full_id).to eq('ESVUFR')
    end
  end

  describe '.generate' do
    it 'generates a group valid for its category' do
      expect(described_class.generate.group).not_to be_nil
    end
  end
end
