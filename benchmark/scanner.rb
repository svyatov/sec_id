# frozen_string_literal: true

# Compare the same workloads against two library trees:
# ruby -I/path/to/baseline/lib benchmark/scanner.rb
# ruby -Ilib benchmark/scanner.rb
# Outputs raw samples as JSON. GC remains enabled during measurement.
require 'benchmark'
require 'json'
require 'sec_id'

iterations = Integer(ENV.fetch('ITERATIONS', '1000'))
samples = Integer(ENV.fetch('SAMPLES', '5'))
paragraph = 'Portfolio: US5949181045, DE000BAY0017 and 2046251 plus BIC DEUTDEFF500 with ' \
            'noise word1 word2 and 037833100 in the same paragraph for the scanner to chew on.'
dense = (SecID.identifiers.map(&:example) * 5).join('; ')
noise = (['hello world word1 word2'] * 25).join(' ')
cases = {
  'paragraph' => -> { SecID.extract(paragraph) },
  'dense' => -> { SecID.extract(dense) },
  'noise' => -> { SecID.extract(noise) },
  'filtered' => -> { SecID.extract(dense, types: %i[isin cusip]) },
  'ambiguous' => -> { SecID.extract('514000; 100000; 2046251; QZ00000F38H0') },
  'compound' => -> { SecID.extract('APPLE INC/SH; AAPL  210917C00150000') }
}.freeze

results = cases.transform_values do |operation|
  100.times { operation.call }
  matches = operation.call.map { |match| [match.type, match.raw, match.range.to_s, match.identifier.to_s] }
  measurements = Array.new(samples) do
    GC.start
    before = GC.stat(:total_allocated_objects)
    seconds = Benchmark.realtime { iterations.times { operation.call } }
    { seconds: seconds, allocations_per_call: (GC.stat(:total_allocated_objects) - before).fdiv(iterations) }
  end
  { matches: matches, measurements: measurements }
end

puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, iterations: iterations, samples: samples, results: results)
