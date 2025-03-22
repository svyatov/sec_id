# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecID do
  it 'has a version number' do
    expect(SecID::VERSION).not_to be_nil
  end
end
