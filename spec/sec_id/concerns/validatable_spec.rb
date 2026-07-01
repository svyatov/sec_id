# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecID::Validatable do
  describe '#valid_length? with discrete-length (Array) ID_LENGTH' do
    let(:klass) do
      Class.new(SecID::Base) do
        const_set(:ID_LENGTH, [8, 11])
        const_set(:VALID_CHARS_REGEX, /\A[A-Z0-9]+\z/)
        const_set(:ID_REGEX, /\A(?<identifier>[A-Z0-9]+)\z/)
        def initialize(str) # rubocop:disable Lint/MissingSuper
          @identifier = parse(str)[:identifier]
        end
      end
    end

    def valid_length_for?(length)
      klass.new('A' * length).send(:valid_length?)
    end

    it 'accepts only the listed lengths' do
      expect(valid_length_for?(8)).to be(true)
      expect(valid_length_for?(11)).to be(true)
    end

    it 'rejects lengths outside and between the listed values' do
      [7, 9, 10, 12].each do |length|
        expect(valid_length_for?(length)).to be(false)
      end
    end
  end
end
