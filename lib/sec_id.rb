# frozen_string_literal: true

require 'set'
require 'sec_id/version'
require 'sec_id/concerns/normalizable'
require 'sec_id/concerns/check_digit_algorithms'
require 'sec_id/base'
require 'sec_id/isin'
require 'sec_id/cusip'
require 'sec_id/sedol'
require 'sec_id/figi'
require 'sec_id/lei'
require 'sec_id/iban'
require 'sec_id/cik'
require 'sec_id/occ'
require 'sec_id/wkn'
require 'sec_id/valoren'
require 'sec_id/cei'
require 'sec_id/cfi'
require 'sec_id/fisn'

module SecId
  Error = Class.new(StandardError)
  InvalidFormatError = Class.new(Error)
end
