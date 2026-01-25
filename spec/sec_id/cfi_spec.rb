# frozen_string_literal: true

RSpec.describe SecId::CFI do
  let(:cfi) { described_class.new(cfi_code) }

  # Edge cases - applicable to all identifiers
  it_behaves_like 'handles edge case inputs'

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

      it 'has no check digit' do
        expect(cfi.has_check_digit?).to be(false)
        expect(cfi.check_digit).to be_nil
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
      'HCXXXX' => { category: :non_listed_options, group: :call_options },
      'IFXXXX' => { category: :spot, group: :foreign_exchange },
      'JFXXXX' => { category: :forwards, group: :foreign_exchange },
      'KRXXXX' => { category: :strategies, group: :rates },
      'LSXXXX' => { category: :financing, group: :loan_lease },
      'TIXXXX' => { category: :referential_instruments, group: :currencies },
      'MCXXXX' => { category: :miscellaneous, group: :combined_instruments }
    }.each do |code, expected|
      it "returns #{expected[:category]}/#{expected[:group]} for #{code}" do
        cfi = described_class.new(code)
        expect(cfi.category).to eq(expected[:category])
        expect(cfi.group).to eq(expected[:group])
      end
    end
  end

  describe 'equity predicate methods' do
    context 'when equity with voting rights (ESVUFR)' do
      let(:cfi_code) { 'ESVUFR' }

      it { expect(cfi.equity?).to be(true) }
      it { expect(cfi.voting?).to be(true) }
      it { expect(cfi.non_voting?).to be(false) }
      it { expect(cfi.restricted_voting?).to be(false) }
      it { expect(cfi.enhanced_voting?).to be(false) }
      it { expect(cfi.no_restrictions?).to be(true) }
      it { expect(cfi.restrictions?).to be(false) }
      it { expect(cfi.fully_paid?).to be(true) }
      it { expect(cfi.nil_paid?).to be(false) }
      it { expect(cfi.partly_paid?).to be(false) }
      it { expect(cfi.registered?).to be(true) }
      it { expect(cfi.bearer?).to be(false) }
    end

    context 'when equity with non-voting, restrictions, nil-paid, bearer (ESNTOB)' do
      let(:cfi_code) { 'ESNTOB' }

      it { expect(cfi.equity?).to be(true) }
      it { expect(cfi.voting?).to be(false) }
      it { expect(cfi.non_voting?).to be(true) }
      it { expect(cfi.restrictions?).to be(true) }
      it { expect(cfi.no_restrictions?).to be(false) }
      it { expect(cfi.nil_paid?).to be(true) }
      it { expect(cfi.fully_paid?).to be(false) }
      it { expect(cfi.bearer?).to be(true) }
      it { expect(cfi.registered?).to be(false) }
    end

    context 'when equity with restricted voting (ESRXXX)' do
      let(:cfi_code) { 'ESRXXX' }

      it { expect(cfi.restricted_voting?).to be(true) }
    end

    context 'when equity with enhanced voting (ESEXXX)' do
      let(:cfi_code) { 'ESEXXX' }

      it { expect(cfi.enhanced_voting?).to be(true) }
    end

    context 'when equity with partly paid (ESXXPX)' do
      let(:cfi_code) { 'ESXXPX' }

      it { expect(cfi.partly_paid?).to be(true) }
    end

    context 'when non-equity (DBXXXX)' do
      let(:cfi_code) { 'DBXXXX' }

      it { expect(cfi.equity?).to be(false) }
      it { expect(cfi.voting?).to be(false) }
      it { expect(cfi.non_voting?).to be(false) }
      it { expect(cfi.restrictions?).to be(false) }
      it { expect(cfi.fully_paid?).to be(false) }
      it { expect(cfi.bearer?).to be(false) }
      it { expect(cfi.registered?).to be(false) }
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

  describe '.valid_format?' do
    context 'when format is valid' do
      it 'returns true for valid formats' do
        expect(described_class.valid_format?('ESXXXX')).to be(true)
        expect(described_class.valid_format?('DBXXXX')).to be(true)
      end
    end

    context 'when format is invalid' do
      it 'returns false for wrong length' do
        expect(described_class.valid_format?('ESXXX')).to be(false)
      end

      it 'returns false for invalid category' do
        expect(described_class.valid_format?('QSXXXX')).to be(false)
      end

      it 'returns false for invalid group' do
        expect(described_class.valid_format?('EZXXXX')).to be(false)
      end
    end
  end

  describe '#to_s' do
    let(:cfi_code) { 'ESVUFR' }

    it 'returns the identifier' do
      expect(cfi.to_s).to eq('ESVUFR')
    end
  end

  describe '#full_number' do
    let(:cfi_code) { 'esvufr' }

    it 'returns the normalized (uppercased) full number' do
      expect(cfi.full_number).to eq('ESVUFR')
    end
  end

  describe 'X attribute handling in predicates' do
    context 'when all attributes are X (not applicable)' do
      let(:cfi_code) { 'ESXXXX' }

      it { expect(cfi.equity?).to be(true) }
      it { expect(cfi.voting?).to be(false) }
      it { expect(cfi.non_voting?).to be(false) }
      it { expect(cfi.restricted_voting?).to be(false) }
      it { expect(cfi.enhanced_voting?).to be(false) }
      it { expect(cfi.restrictions?).to be(false) }
      it { expect(cfi.no_restrictions?).to be(false) }
      it { expect(cfi.fully_paid?).to be(false) }
      it { expect(cfi.nil_paid?).to be(false) }
      it { expect(cfi.partly_paid?).to be(false) }
      it { expect(cfi.bearer?).to be(false) }
      it { expect(cfi.registered?).to be(false) }
    end
  end
end
