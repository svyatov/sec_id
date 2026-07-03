# frozen_string_literal: true

require_relative '../../tasks/cfi_signature_generator'

# Drift guard: the committed CFI dynamic-method signatures are generated from
# SecID::CFI::Tables. If Tables changes without regenerating, these fail so the
# signatures can't silently desync from the source of truth.
RSpec.describe 'CFI generated signatures' do # rubocop:disable RSpec/DescribeClass
  {
    'sig/sec_id/cfi/field.rbs' => :field_rbs,
    'sig/sec_id/cfi/attribute_set.rbs' => :attribute_set_rbs
  }.each do |relative_path, generator_method|
    it "#{relative_path} is in sync with SecID::CFI::Tables" do
      committed = File.read(File.expand_path("../../#{relative_path}", __dir__))
      regenerated = CFISignatureGenerator.public_send(generator_method)

      expect(committed).to eq(regenerated),
                           "#{relative_path} is out of sync with SecID::CFI::Tables — run `rake sig:cfi`"
    end
  end

  it 'emits symbols and meanings in a stable, sorted, de-duplicated order' do
    symbols = CFISignatureGenerator.field_predicate_symbols
    meanings = CFISignatureGenerator.attribute_meanings

    expect(symbols).to eq(symbols.uniq.sort)
    expect(meanings).to eq(meanings.uniq.sort)
  end
end
