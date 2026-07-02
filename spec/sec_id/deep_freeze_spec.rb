# frozen_string_literal: true

RSpec.describe SecID::DeepFreeze do
  describe '.call' do
    it 'recursively freezes nested hashes and arrays, returning the same object' do
      structure = { list: [{ leaf: +'x' }], scalar: +'y' }
      result = described_class.call(structure)

      expect(result).to be(structure)
      expect(structure).to be_frozen
      expect(structure[:list]).to be_frozen
      expect(structure[:list].first).to be_frozen
      expect(structure[:list].first[:leaf]).to be_frozen
    end

    it 'freezes a bare scalar' do
      expect(described_class.call(+'z')).to be_frozen
    end
  end
end
