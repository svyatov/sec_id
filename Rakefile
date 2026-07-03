# frozen_string_literal: true

require 'English'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'steep/rake_task'
require 'yard'

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

Steep::RakeTask.new

# Set is a core class in rbs 4.0 (always loaded); only `date` is a stdlib library.
RBS_LIBS = %w[date].freeze

desc 'Validate RBS signatures'
task :rbs do
  sh "rbs #{RBS_LIBS.map { |lib| "-r #{lib}" }.join(' ')} -I sig validate"
end

# Named `steep:report`, not `steep:stats`: `Steep::RakeTask.new` already defines a
# `steep:stats` task, and Rake appends to (rather than replaces) a re-declared task —
# a collision would concatenate both descriptions in `rake -T` and run stats twice.
desc 'Report Steep type coverage per file (table view)'
task 'steep:report' do
  sh 'steep stats --format=table'
end

# The theoretical target is zero untyped calls, but the residual set is intrinsic, not
# a gap to close. Some receivers are genuinely nilable at runtime (the valid?/errors
# design returns nil readers for invalid input); the rest are idioms RBS/stdlib can't
# express (nilable stdlib MatchData in the scanner, Array#map!'s type-invariance,
# freeze-after-case in DeepFreeze, widening CFI tables). Forcing them to zero would only
# add dead "can't-happen" guards to check-digit math, so RBS::Test verifies them at
# runtime instead. The gate pins that floor so coverage cannot silently regress; lower
# BASELINE whenever it drops.
STEEP_UNTYPED_BASELINE = 118

desc 'Fail if Steep reports more untyped calls than the pinned baseline'
task 'steep:coverage' do
  # Fail closed: `steep stats` exits 0 even when a file fails to type-check (emitting an
  # `error`-status row with 0 in every count column), so trusting a bare sum would let a
  # broken run silently score 0 untyped and pass. Guard the exit status, empty output, and
  # any non-success row before counting.
  csv = `steep stats --format=csv`
  abort "steep stats failed (exit #{$CHILD_STATUS.exitstatus})" unless $CHILD_STATUS.success?

  rows = csv.lines.drop(1)
  abort 'steep stats produced no output — cannot verify coverage' if rows.empty?

  unchecked = rows.reject { |line| line.split(',')[2] == 'success' }
  unless unchecked.empty?
    abort "steep did not fully check #{unchecked.size} file(s); run `rake steep` to see the errors"
  end

  untyped = rows.sum { |line| line.split(',')[4].to_i }
  if untyped > STEEP_UNTYPED_BASELINE
    abort "Type coverage regressed: #{untyped} untyped call(s) > baseline #{STEEP_UNTYPED_BASELINE}. " \
          'Add a sig type for the new call, or bump STEEP_UNTYPED_BASELINE if it is an intrinsic idiom.'
  end
  puts "Type coverage: #{untyped} untyped call(s) (baseline #{STEEP_UNTYPED_BASELINE})"
end

desc 'Regenerate CFI dynamic-method signatures from SecID::CFI::Tables'
task 'sig:cfi' do
  require_relative 'tasks/cfi_signature_generator'
  File.write('sig/sec_id/cfi/field.rbs', CFISignatureGenerator.field_rbs)
  File.write('sig/sec_id/cfi/attribute_set.rbs', CFISignatureGenerator.attribute_set_rbs)
  puts 'Regenerated sig/sec_id/cfi/{field,attribute_set}.rbs'
end

desc 'Verify actual runtime values against the RBS signatures (RBS::Test)'
task 'rbs:test' do
  ENV['RBS_TEST_TARGET'] = 'SecID::*'
  ENV['RBS_TEST_OPT'] = "-I sig #{RBS_LIBS.map { |lib| "-r #{lib}" }.join(' ')}"
  ENV['RBS_TEST_DOUBLE_SUITE'] = 'rspec'
  ENV['RUBYOPT'] = "-r rbs/test/setup #{ENV.fetch('RUBYOPT', nil)}".strip
  # reenable first: Rake no-ops a repeat #invoke of an already-run task in the same process,
  # so `rake spec rbs:test` (or any composite that ran :spec earlier) would otherwise skip
  # the instrumented run and pass having verified nothing.
  Rake::Task[:spec].reenable
  Rake::Task[:spec].invoke
end

Rake::Task['release:rubygem_push'].enhance(['fetch_otp'])

task :fetch_otp do
  ENV['GEM_HOST_OTP_CODE'] = `op item get "RubyGems" --account my --otp`.strip
end

desc 'Run validation/detection throughput and allocation benchmarks'
task :bench do
  ruby '-Ilib benchmark/run.rb'
end

YARD::Rake::YardocTask.new

namespace :yard do
  desc 'Fail unless 100% of the public API is documented'
  task :stats do
    out = `yard stats --list-undoc`
    puts out
    abort 'Undocumented public API found' unless out.include?('100.00% documented')
  end
end

task default: %i[rubocop rbs spec]
