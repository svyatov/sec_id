# frozen_string_literal: true

RSpec.describe SecId::Base do
  describe '#initialize' do
    it 'raises NotImplementedError' do
      expect { described_class.new('test') }.to raise_error(NotImplementedError)
    end
  end

  describe '#calculate_check_digit' do
    it 'raises NotImplementedError' do
      base = described_class.allocate
      expect { base.calculate_check_digit }.to raise_error(NotImplementedError)
    end
  end

  describe '#id_digits' do
    it 'raises NotImplementedError' do
      base = described_class.allocate
      expect { base.send(:id_digits) }.to raise_error(NotImplementedError)
    end
  end
end
