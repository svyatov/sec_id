# frozen_string_literal: true

# Precision simulation for SecID#suggest (the human-error net).
# Run with: ruby -Ilib benchmark/suggest_precision.rb
#
# For each checksum type it draws valid identifiers via `.generate`, injects a single
# known error — a homoglyph substitution and, separately, an adjacent transposition —
# at random BODY positions, runs `suggest`, and measures three distinct axes:
#
#   - reachability: fraction of injected homoglyph typos whose mistyped character stays
#     in the type's charset. An out-of-charset typo (O-for-0, I-for-1 in the vowel-free
#     SEDOL/FIGI/DTI/UPI) is unparseable, so it can never be repaired — expected < 100%
#     only for those four types.
#   - repairable: fraction of (reachable) typos that yield a format-valid, checksum-FAILING
#     input — the engine's actual domain. Below 100% because some typos break structural
#     format instead (a letter in IBAN's numeric BBAN, a digit in a country code) or stay
#     coincidentally valid (the checksum blind spot).
#   - correction: over repairable typos, the fraction where the original identifier is
#     recovered — present among the candidates, and separately, the TOP-ranked body
#     candidate. Recovery is ~100% by construction (the reverting edit is always
#     enumerated and always re-validates); top-rank dips when a coincidental homoglyph
#     out-ranks the true fix.
#
# Analysis harness only — not shipped in the gem. The RNG is seeded for reproducibility.

require 'sec_id'

SEED = 20_260_714
SAMPLES = 1_000
TYPES = %i[isin cusip sedol figi lei iban cei dti upi].freeze
HOMOGLYPHS = SecID::Suggestable::HOMOGLYPHS
HEADERS = %w[type h-reach h-repair h-found h-top t-found t-top set-avg set-max].freeze

Trial = Struct.new(:reachable, :repairable, :corrected, :top_body, :set_size)

# Body positions of a valid identifier — the characters that are not the check field.
# Only IBAN carries its two check digits mid-string (positions 2-3); the rest trail.
def body_positions(klass, valid)
  return (0...valid.length).to_a - [2, 3] if klass == SecID::IBAN

  (0...klass.new(valid).identifier.length).to_a
end

def measure(klass, valid, typo, reachable)
  return Trial.new(false, false, false, false, 0) unless reachable

  instance = klass.new(typo)
  return Trial.new(true, false, false, false, 0) unless instance.send(:valid_format?) && !instance.valid?

  outcome(klass.suggest(typo), valid)
end

def outcome(suggestions, valid)
  body = suggestions.reject { |s| s.edit == :checksum }
  Trial.new(true, true, suggestions.any? { |s| s.to_s == valid }, body.first&.to_s == valid, suggestions.size)
end

# Inject a homoglyph typo: pick a body char with a homoglyph partner, type the partner.
def homoglyph_trial(klass, valid, rng)
  positions = body_positions(klass, valid).select { |i| HOMOGLYPHS.key?(valid[i]) }
  return if positions.empty?

  index = positions.sample(random: rng)
  typo_char = HOMOGLYPHS.fetch(valid[index]).sample(random: rng)
  typo = valid.dup.tap { |s| s[index] = typo_char }
  measure(klass, valid, typo, typo_char.match?(klass::VALID_CHARS_REGEX))
end

# Inject an adjacent transposition of two differing body characters (always in-charset).
def transposition_trial(klass, valid, rng)
  pairs = adjacent_body_pairs(klass, valid)
  return if pairs.empty?

  left, right = pairs.sample(random: rng)
  typo = valid.dup.tap { |s| s[left], s[right] = s[right], s[left] }
  measure(klass, valid, typo, true)
end

def adjacent_body_pairs(klass, valid)
  body_positions(klass, valid).each_cons(2).select { |a, b| b == a + 1 && valid[a] != valid[b] }
end

def collect(klass, &trial)
  rng = Random.new(SEED)
  Array.new(SAMPLES) { trial.call(klass, klass.generate(random: rng).to_s, rng) }.compact
end

def rate(trials, &)
  return 0.0 if trials.empty?

  trials.count(&).fdiv(trials.size)
end

def avg(values)
  values.empty? ? 0.0 : values.sum.fdiv(values.size)
end

# Flat metric aggregation — inherently many trivial rate() calls.
def metrics(key, homoglyph, transposition)
  reachable = homoglyph.select(&:reachable)
  h_ok = reachable.select(&:repairable)
  t_ok = transposition.select(&:repairable)
  sizes = (h_ok + t_ok).map(&:set_size)
  {
    key: key, reachability: rate(homoglyph, &:reachable), h_repairable: rate(reachable, &:repairable),
    h_found: rate(h_ok, &:corrected), h_top: rate(h_ok, &:top_body),
    t_found: rate(t_ok, &:corrected), t_top: rate(t_ok, &:top_body),
    avg_size: avg(sizes), max_size: sizes.max || 0
  }
end

def summarize(key)
  klass = SecID[key]
  metrics(key, collect(klass, &method(:homoglyph_trial)), collect(klass, &method(:transposition_trial)))
end

def pct(value)
  format('%<value>5.1f%%', value: value * 100)
end

def render(cells)
  head, *rest = cells
  [head.to_s.ljust(7), *rest.map { |cell| cell.to_s.rjust(9) }].join
end

def data_row(row)
  render([
           row[:key], pct(row[:reachability]), pct(row[:h_repairable]), pct(row[:h_found]), pct(row[:h_top]),
           pct(row[:t_found]), pct(row[:t_top]), format('%<n>.1f', n: row[:avg_size]), row[:max_size],
         ])
end

def mean(rows, key)
  rows.sum { |row| row[key] }.fdiv(rows.size)
end

rows = TYPES.map { |key| summarize(key) }
divider = '-' * render(HEADERS).length

puts "SecID#suggest precision simulation — #{SAMPLES} samples/type, seed #{SEED}, Ruby #{RUBY_VERSION}"
puts '(homoglyph = h, transposition = t; found/top are over repairable typos)'
puts
puts render(HEADERS)
puts divider
rows.each { |row| puts data_row(row) }
puts divider
puts
puts 'Headline (mean across the 9 checksum types):'
puts "  in-charset homoglyph reachability:      #{pct(mean(rows, :reachability))}"
puts "  correction rate (repairable homoglyph): #{pct(mean(rows,
                                                           :h_found))}  (top-ranked body: #{pct(mean(rows, :h_top))})"
puts "  correction rate (repairable transp.):   #{pct(mean(rows,
                                                           :t_found))}  (top-ranked body: #{pct(mean(rows, :t_top))})"
