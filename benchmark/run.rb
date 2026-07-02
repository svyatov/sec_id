# frozen_string_literal: true

# Throughput and allocation benchmark for the validation/detection hot paths.
# Run with: bundle exec rake bench  (or: bundle exec ruby benchmark/run.rb)
#
# Numbers are machine-dependent — use this to catch *regressions* across a
# change (run before, run after, compare), not as an absolute target.

require 'benchmark/ips'
require 'sec_id'

# Representative inputs covering each hot path.
VALID_ISIN  = 'US5949181045'
BAD_CD_ISIN = 'US5949181040' # valid format, wrong check digit
CUSIP       = '594918104'
SEDOL       = '2046251'
CFI         = 'ESVUFR' # exercises the per-position attribute lookups
# Deliberate, deterministic match set: 2 ISIN, 1 SEDOL, 1 CUSIP, 1 BIC. Avoid
# stray 8-letter words, which can validate as a BIC8 (e.g. "Holdings" -> HOLD/IN/GS).
TEXT = 'Portfolio: US5949181045, DE000BAY0017 and 2046251 plus BIC DEUTDEFF500 with ' \
       'noise word1 word2 and 037833100 in the same paragraph for the scanner to chew on.'

CASES = {
  'ISIN.valid? (known type)' => -> { SecID::ISIN.valid?(VALID_ISIN) },
  'ISIN.valid? (bad check digit)' => -> { SecID::ISIN.valid?(BAD_CD_ISIN) },
  'CUSIP.valid?' => -> { SecID::CUSIP.valid?(CUSIP) },
  'SEDOL.valid?' => -> { SecID::SEDOL.valid?(SEDOL) },
  'CFI.valid?' => -> { SecID::CFI.valid?(CFI) },
  'SecID.valid? (unknown -> detector)' => -> { SecID.valid?(VALID_ISIN) },
  'SecID.detect' => -> { SecID.detect(VALID_ISIN) },
  'SecID.parse' => -> { SecID.parse(VALID_ISIN) },
  'SecID.extract (paragraph)' => -> { SecID.extract(TEXT) }
}.freeze

puts "Ruby #{RUBY_VERSION}\n\n== Throughput =="
Benchmark.ips do |x|
  CASES.each { |label, callable| x.report(label, &callable) }
end

puts "\n== Allocations (objects per call) =="
CASES.each do |label, callable|
  n = 50_000
  GC.start
  GC.disable
  before = GC.stat(:total_allocated_objects)
  n.times { callable.call }
  per = (GC.stat(:total_allocated_objects) - before).fdiv(n)
  GC.enable
  printf("%<label>-38s %<per>7.1f\n", label: label, per: per)
end
