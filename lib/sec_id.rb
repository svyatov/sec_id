# frozen_string_literal: true

require 'set'
require 'sec_id/version'
require 'sec_id/base'
require 'sec_id/isin'
require 'sec_id/cusip'
require 'sec_id/sedol'
require 'sec_id/figi'
require 'sec_id/cik'
require 'sec_id/occ'

module SecId
  Error = Class.new(StandardError)
  InvalidFormatError = Class.new(Error)
end
