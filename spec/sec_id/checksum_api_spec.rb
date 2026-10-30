# frozen_string_literal: true

RSpec.describe 'checksum API without the v7 bridge' do # rubocop:disable RSpec/DescribeClass
  SecID.identifiers.each do |klass|
    describe klass do
      let(:instance) { klass.new(klass.example) }

      it 'exposes only the canonical capability predicate' do
        expect(klass).to respond_to(:has_checksum?)
        expect(klass).not_to respond_to(:has_check_digit?)
      end

      next unless klass.has_checksum?

      it 'exposes only canonical checksum methods' do
        expect(klass).to respond_to(:checksum)
        expect(klass).not_to respond_to(:check_digit)
        expect(instance).to respond_to(:checksum, :calculate_checksum)
        expect(instance).not_to respond_to(:check_digit, :calculate_check_digit)
      end

      it 'serializes the checksum without a legacy key' do
        expect(instance.to_h[:components]).to include(:checksum)
        expect(instance.to_h[:components]).not_to have_key(:check_digit)
        expect(instance.deconstruct_keys(nil)).not_to have_key(:check_digit)
      end
    end
  end

  it 'raises the canonical error for an invalid checksum' do
    expect { SecID::ISIN.new('US5949181040').validate! }.to raise_error(SecID::InvalidChecksumError)
    expect(SecID.const_defined?(:InvalidCheckDigitError, false)).to be(false)
  end
end
