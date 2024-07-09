# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecId do
  it 'has a version number' do
    expect(SecId::VERSION).not_to be_nil
  end
end
