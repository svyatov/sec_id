# frozen_string_literal: true

require 'set'
require 'sec_id/version'
require 'sec_id/base'
require 'sec_id/isin'
require 'sec_id/cusip'

module SecId
  Error = Class.new(StandardError)
  InvalidFormatError = Class.new(Error)
end
