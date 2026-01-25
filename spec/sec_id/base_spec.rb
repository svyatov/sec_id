# frozen_string_literal: true

RSpec.describe SecId::Base do
  describe '#initialize' do
    it 'raises NotImplementedError' do
      expect { described_class.new('test') }.to raise_error(NotImplementedError)
    end
  end

  describe '#calculate_check_digit' do
    it 'raises NotImplementedError when has_check_digit? is true' do
      base = described_class.allocate
      allow(base).to receive(:has_check_digit?).and_return(true)
      expect { base.calculate_check_digit }.to raise_error(NotImplementedError)
    end

    it 'returns nil when has_check_digit? is false' do
      base = described_class.allocate
      allow(base).to receive(:has_check_digit?).and_return(false)
      expect(base.calculate_check_digit).to be_nil
    end
  end

  describe '#id_digits' do
    it 'raises NotImplementedError' do
      base = described_class.allocate
      expect { base.send(:id_digits) }.to raise_error(NotImplementedError)
    end
  end
end
