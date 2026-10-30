# frozen_string_literal: true

# Run identical workloads against two library trees:
# ruby -I/path/to/baseline/lib benchmark/checksums.rb
# ruby -Ilib benchmark/checksums.rb
# Outputs raw samples as JSON. GC remains enabled during measurement.
require 'benchmark'
require 'json'
require 'sec_id'

iterations = Integer(ENV.fetch('ITERATIONS', '10000'))
samples = Integer(ENV.fetch('SAMPLES', '5'))
text = 'US5949181045 037833100 BBG000BLNNH6 A0BCDEFGH1'
cases = {
  'isin_valid' => -> { SecID::ISIN.valid?('US5949181045') },
  'cusip_valid' => -> { SecID::CUSIP.valid?('037833100') },
  'cei_valid' => -> { SecID::CEI.valid?('A0BCDEFGH1') },
  'figi_valid' => -> { SecID::FIGI.valid?('BBG000BLNNH6') },
  'isin_bad_checksum' => -> { SecID::ISIN.valid?('US5949181040') },
  'detect' => -> { SecID.detect('US5949181045') },
  'parse' => -> { SecID.parse('US5949181045') },
  'extract' => -> { SecID.extract(text) },
  'suggest' => -> { SecID::ISIN.suggest('US5949181040') }
}.freeze

results = cases.transform_values do |operation|
  1000.times { operation.call }
  Array.new(samples) do
    GC.start
    before = GC.stat(:total_allocated_objects)
    seconds = Benchmark.realtime { iterations.times { operation.call } }
    { seconds: seconds, allocations_per_call: (GC.stat(:total_allocated_objects) - before).fdiv(iterations) }
  end
end

puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, iterations: iterations, samples: samples, results: results)
