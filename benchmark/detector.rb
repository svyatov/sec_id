# frozen_string_literal: true

# ruby -I/path/to/baseline/lib benchmark/detector.rb
# ruby -Ilib benchmark/detector.rb
# Raw samples use the same inputs with GC enabled in both library trees.
require 'benchmark'
require 'json'
require 'sec_id'

iterations = Integer(ENV.fetch('ITERATIONS', '10000'))
samples = Integer(ENV.fetch('SAMPLES', '5'))
inputs = {
  'isin' => 'US5949181045', 'cusip' => '037833100', 'wkn' => '514000',
  'figi' => 'BBG000BLNNH6', 'cfi_collision' => 'ESVUFR', 'upi_collision' => 'QZ6VLPW19DZ6',
  'upi' => 'QZT6XRWJ7Z2D',
  'fisn' => 'APPLE INC/SH', 'occ' => 'AAPL  210917C00150000',
  'invalid_checksum' => 'US5949181040', 'unsupported_length' => 'A' * 100
}.freeze

results = inputs.to_h do |name, input|
  operations = {
    'parse' => -> { SecID.parse(input)&.class&.type_key },
    'detect' => -> { SecID.detect(input) },
    'valid' => -> { SecID.valid?(input) }
  }
  measurements = operations.transform_values do |operation|
    100.times { operation.call }
    result = operation.call
    runs = Array.new(samples) do
      GC.start
      before = GC.stat(:total_allocated_objects)
      seconds = Benchmark.realtime { iterations.times { operation.call } }
      { seconds: seconds, allocations_per_call: (GC.stat(:total_allocated_objects) - before).fdiv(iterations) }
    end
    { result: result, measurements: runs }
  end
  [name, measurements]
end

puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, iterations: iterations, samples: samples, results: results)
