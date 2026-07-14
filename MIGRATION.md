# Upgrading to SecID 7.0

This guide covers all breaking changes when upgrading from SecID 6.x to 7.0. They are all one
mechanical rename: the **check-digit** concept became **checksum** across the public API —
methods, the error class, the error code, the components key, and documentation vocabulary.
The name was inaccurate on two axes: DTI's and UPI's check value is a `String` (it can be a
letter, not a digit), and LEI and IBAN carry a two-character check value. `checksum` is
type- and count-agnostic.

Nothing about validation or checksum arithmetic changed — every previously valid identifier is
still valid and every computed value is byte-identical. Only names, one error code, and
deprecation warnings changed.

## Quick Reference

| What changed | Before (6.x) | After (7.0) |
|---|---|---|
| Instance/class method | `isin.check_digit`, `SecID::ISIN.check_digit(id)` | `isin.checksum`, `SecID::ISIN.checksum(id)` |
| Calculation method | `isin.calculate_check_digit` | `isin.calculate_checksum` |
| Capability predicate | `SecID::ISIN.has_check_digit?` | `SecID::ISIN.has_checksum?` |
| Error class | `SecID::InvalidCheckDigitError` | `SecID::InvalidChecksumError` |
| **Error code (hard flip)** | `:invalid_check_digit` | `:invalid_checksum` |
| Components / `to_h` / pattern-match key | `{ check_digit: … }` | `{ checksum: … }` |

`restore` / `restore!` and the `Checkable` concern name are unchanged.

**Bridge:** the old method names, the `InvalidCheckDigitError` constant, and the `:check_digit`
components key all keep working through v7 (the methods warn on use); they are removed in v8.
**The one exception is the error code** — `:invalid_check_digit` flips hard to `:invalid_checksum`
at v7 with no bridge, so an error-code matcher must be updated immediately.

## Step-by-Step

### 1. Update Gemfile

```ruby
gem 'sec_id', '~> 7.0'
```

Then run `bundle update sec_id`.

### 2. Rename method calls (deprecated aliases warn through v7)

```ruby
# Before (6.x)
isin.check_digit
isin.calculate_check_digit
SecID::ISIN.check_digit('US594918104')
SecID::ISIN.has_check_digit?

# After (7.0)
isin.checksum
isin.calculate_checksum
SecID::ISIN.checksum('US594918104')
SecID::ISIN.has_checksum?
```

The old names still work through v7 but emit a deprecation warning on every call and are removed
in v8. See step 6 to silence them if you cannot migrate every call site yet.

### 3. Rename the rescued error class

```ruby
# Before (6.x)
rescue SecID::InvalidCheckDigitError => e

# After (7.0)
rescue SecID::InvalidChecksumError => e
```

`SecID::InvalidCheckDigitError` remains as a constant alias of `SecID::InvalidChecksumError`
through v7 (it is the *same class object*, so `rescue` under either name catches the same error),
and is removed in v8.

The constant alias emits **no** deprecation warning at runtime (it is a plain constant, not a
warned method), so `-W` output won't reveal your rescue sites — find them statically:

```bash
grep -rEn 'InvalidCheckDigitError' app/ lib/ spec/
```

### 4. Update error-code matchers (hard flip — no bridge)

The `:invalid_check_digit` code in `errors.details` and `explain` output is replaced by
`:invalid_checksum` with **no dual emission** — emitting both would duplicate `errors.details`
entries. This is the only change with no v7 bridge, so update any matcher immediately.

```ruby
# Before (6.x)
isin.errors.details.first[:error] == :invalid_check_digit
SecID.explain('US5949181040', types: [:isin])[:candidates].first[:errors]
#   => [{ error: :invalid_check_digit, message: "Check digit '0' is invalid, expected '5'" }]

# After (7.0)
isin.errors.details.first[:error] == :invalid_checksum
SecID.explain('US5949181040', types: [:isin])[:candidates].first[:errors]
#   => [{ error: :invalid_checksum, message: "Checksum '0' is invalid, expected '5'" }]
```

If you use the opt-in ActiveModel/Rails validator with `details: true`, the surfaced reason
follows the same flip: an invalid checksum now reports `:invalid_checksum`.

### 5. Migrate pattern matches and `to_h` readers before v8

`components` (and therefore `to_h` and `deconstruct_keys`) carries **both** `:checksum` and the
deprecated `:check_digit` key through v7, so existing pattern matches keep working. The
`:check_digit` key is removed in v8 — migrate to `:checksum` before then.

```ruby
# Both work through v7, binding the same value:
isin => { check_digit: }   # deprecated, removed in v8
isin => { checksum: }      # canonical

isin.to_h[:components]
#   => { country_code: 'US', nsin: '594918104', checksum: 5, check_digit: 5 }
```

Reading the `:check_digit` key also emits **no** warning (the value mirrors `:checksum`), so grep
for the call sites rather than relying on stderr:

```bash
grep -rEn ':check_digit\b|check_digit:' app/ lib/ spec/
```

### 6. Silencing the deprecation warnings

The method aliases warn via `Kernel#warn` on every call, visible at Ruby's default verbosity.
If you cannot migrate every call site before v7, silence them one of these ways:

```ruby
# Process-wide, at the lowest verbosity (also silences other Ruby warnings):
$VERBOSE = nil            # equivalent to running with -W0

# Or filter only SecID's deprecations with an app-level Warning override:
module SecIDDeprecationSilencer
  def warn(message, category: nil, **)
    super unless message.to_s.include?('SecID: `')
  end
end
Warning.extend(SecIDDeprecationSilencer)
```

The warnings are intentionally on by default (not routed through `Warning[:deprecated]`, which
Ruby leaves off) so the migration signal is visible without opting in.

---

# Upgrading to SecID 6.0

This guide covers all breaking changes when upgrading from SecID 5.x to 6.0. Every one is
confined to `SecID::CFI`, which became a full ISO 10962:2021 classifier (strict attribute
validation, corrected group tables, and a new `#decode` classification object replacing the
old category-wide predicates).

## Quick Reference

| What changed | Before | After |
|---|---|---|
| CFI attribute validation is strict | `CFI.valid?('ESZZZZ')` was `true` | now `false` — positions 3-6 must match the ISO tables for the group |
| CFI group letters/symbols corrected | old `H`/`D`/`L`/`T` groups; `FM`/`IM`/`JM`/`LM` | ISO 10962:2021 groups; e.g. `LS` → `:securities_lending`, `TI` → `:indices` |
| Equity predicates removed | `cfi.voting?`, `cfi.fully_paid?`, … | `cfi.decode.attributes.voting_right.voting?`, … |
| `equity?` (category-wide) removed | `cfi.equity?` | `cfi.decode.category.equity?` |
| `no_restrictions?` uses ISO name | `cfi.no_restrictions?` | `cfi.decode.attributes.ownership_restrictions.free_of_restrictions?` |

## Step-by-Step

### 1. Update Gemfile

```ruby
gem 'sec_id', '~> 6.0'
```

Then run `bundle update sec_id`.

### 2. Expect stricter CFI validation

`SecID::CFI.valid?` now validates positions 3-6 against the ISO 10962:2021 attribute tables
for every category, not just the code's shape. Codes carrying attribute letters outside the
tables were accepted before and are now invalid. There is no leniency option, matching every
other identifier type.

```ruby
# Before (5.x) — shape-only
SecID::CFI.valid?('ESZZZZ')   # => true

# After (6.0) — Z is not a permissible equity attribute
SecID::CFI.valid?('ESZZZZ')   # => false
```

Conversely, real codes the old (incorrect) group tables rejected — notably non-listed options
(`H`), now classified by underlying (`HR` Rates, `HT` Commodities, `HE` Equity, `HC` Credit,
`HF` FX, `HM` Miscellaneous) — now validate. If you generate CFIs as test fixtures,
`SecID::CFI.generate` now samples only table-permitted letters, so every generated code is valid.

### 3. Replace removed CFI predicates with `cfi.decode`

The 12 hardcoded equity predicates (`equity?`, `voting?`, `non_voting?`, `restricted_voting?`,
`enhanced_voting?`, `restrictions?`, `no_restrictions?`, `fully_paid?`, `nil_paid?`,
`partly_paid?`, `bearer?`, `registered?`) are removed — they were category-wide and
semantically wrong for non-equity groups. `cfi.decode` returns a classification whose
category, group, and attributes are each a **field** object; a predicate lives on the field
whose ISO domain defines it, so it can only answer where the concept is meaningful.

```ruby
# Before (5.x)
cfi = SecID::CFI.new('ESVUFR')
cfi.voting?        # => true
cfi.fully_paid?    # => true

# After (6.0)
d = SecID::CFI.new('ESVUFR').decode
d.attributes.voting_right.voting?      # => true
d.attributes.payment_status.fully_paid? # => true
```

Each field exposes `#code` (the CFI letter), `#name` (the symbol), `#label` (the ISO string),
and `<name>?` predicates scoped to its own domain — asking a field a predicate outside its
domain raises `NoMethodError` (e.g. `d.attributes.payment_status.voting?`), which is what
makes the answers unambiguous. `attributes` is an `Enumerable`; look positions up by meaning
with `d.attributes.voting_right` or the nil-safe `d.attributes[:voting_right]`.

`decode` returns `nil` for an invalid CFI, so guard before chaining:

```ruby
SecID::CFI.new('QQXXXX').decode    # => nil
```

Two names do not map name-for-name:

```ruby
# `equity?` was category-wide, not an attribute value:
cfi.equity?                        # before
cfi.decode.category.equity?        # after (or cfi.category == :equity — CFI#category is unchanged)

# `no_restrictions?` uses the ISO value name, on the ownership_restrictions field:
cfi.no_restrictions?                               # before
cfi.decode.attributes.ownership_restrictions.free_of_restrictions?   # after
```

### 4. Check group symbols if you branch on them

Several group symbols changed to match ISO 10962:2021 (e.g. `LS` → `:securities_lending`,
`TI` → `:indices`, `MM` → `:other_assets`) and the phantom `FM`/`IM`/`JM`/`LM` groups were
removed. If you match on `cfi.group`, review `SecID::CFI.groups_for(category_code)` for the
current values.

---

# Upgrading to SecID 5.0

This guide covers all breaking changes when upgrading from SecID 4.x to 5.0.

## Requirements

- **Ruby 3.2+** (was 3.1+)

## Quick Reference

| What changed | Search pattern | Replacement |
|---|---|---|
| Module rename | `SecId::` | `SecID::` |
| Attribute rename | `.full_number` | `.full_id` |
| OCC method removed | `.full_symbol` | `.full_id` |
| ValidationResult rename | `SecID::ValidationResult` | `SecID::Errors` |
| `ValidationResult#valid?` | `result.valid?` | `result.none?` |
| `.validate` return type | `Klass.validate(id)` returns `ValidationResult` | `Klass.validate(id)` returns instance; use `.errors` for errors |
| `EXCEPTION_MAP` rename | `Base::EXCEPTION_MAP` | `Validatable::ERROR_MAP` |
| `.exception_for_error` rename | `.exception_for_error(code)` | `.error_class_for(code)` |
| `format_errors` rename (private) | `def format_errors` | `def detect_errors` |
| `validation_errors` rename (private) | `def validation_errors` | `def error_codes` |
| Instance `restore!` return | `= obj.restore!` | `obj.restore!` (returns `self`) or `= obj.restore` (returns string) |
| Class `restore!` return | `= Klass.restore!(id)` | `Klass.restore!(id)` (returns instance) or `= Klass.restore(id)` (returns string) |
| Instance `normalize!` return | `= obj.normalize!` | `obj.normalize!` (returns `self`) or `= obj.normalized` (returns string) |
| Class `normalize!` removed | `.normalize!(id)` | `.normalize(id)` |
| `valid_format?` removed | `.valid_format?` | `.valid?` or `.validate` |
| `parse` upcase param | `parse(id, upcase: false)` | `parse(id)` (always upcases) |

## Step-by-Step

### 1. Update Gemfile

```ruby
gem 'sec_id', '~> 5.0'
```

Then run `bundle update sec_id`.

### 2. Rename module: SecId → SecID

The module was renamed to match the conventional acronym casing.

```ruby
# Before
SecId::ISIN.valid?('US5949181045')

# After
SecID::ISIN.valid?('US5949181045')
```

Find all occurrences:

```bash
grep -r 'SecId[^A-Z]' app/ lib/ spec/
```

### 3. Rename attribute: full_number → full_id

```ruby
# Before
isin.full_number  # => 'US5949181045'

# After
isin.full_id      # => 'US5949181045'
```

If you used `OCC#full_symbol`, replace it with `#full_id` as well.

Find all occurrences:

```bash
grep -rE '\.(full_number|full_symbol)\b' app/ lib/ spec/
```

### 4. Update restore! usage (returns self now)

In v4, both instance and class `restore!` returned a string. In v5, they return `self`/instance for chaining. Use `restore` (without bang) to get the string.

```ruby
# Before (v4) — restore! returned a string
id_string = isin.restore!

# After (v5) — choose one:
id_string = isin.restore        # string return (new method)
isin.restore!                   # mutates and returns self

# Class-level
id_string = SecID::ISIN.restore('US594918104')    # returns string
instance  = SecID::ISIN.restore!('US594918104')   # returns instance
```

### 5. Update normalize! usage (returns self now)

Applies to CIK, OCC, and Valoren — the only types with normalization in v4.

```ruby
# Before (v4) — normalize! returned a string
normalized = cik.normalize!

# After (v5) — choose one:
normalized = cik.normalized     # string return (new method)
cik.normalize!                  # mutates and returns self

# Class-level .normalize! removed — use .normalize
# Before
SecId::CIK.normalize!('1094517')

# After
SecID::CIK.normalize('1094517')   # => '0001094517'
```

Note: In v5, all identifier types support normalization, not just CIK/OCC/Valoren.

### 6. Remove calls to deleted methods

**`valid_format?` / `.valid_format?`** — removed from public API. Use `valid?` for boolean checks or `errors` for details:

```ruby
# Before
SecId::ISIN.valid_format?('US5949181045')

# After
SecID::ISIN.valid?('US5949181045')
# or for detailed errors:
SecID::ISIN.validate('US5949181045').messages
```

**`OCC#full_symbol`** — use `#full_id`:

```ruby
# Before
occ.full_symbol

# After
occ.full_id
```

### 7. Update parse calls in custom subclasses

If you subclass `SecID::Base` and call `parse` with `upcase: false`, remove that parameter. `parse` now always upcases input.

```ruby
# Before
parse(id, upcase: false)

# After
parse(id)
```

### 8. Handle now-private Luhn helpers

If you subclass `SecID::Base` with `Checkable` and call Luhn helper methods directly (`luhn_sum_double_add_double`, `luhn_sum_indexed`, `luhn_sum_standard`, etc.), these are now private. Use `calculate_check_digit` instead.

### 9. Update exception handling

The module rename affects exception class references:

```ruby
# Before
rescue SecId::InvalidFormatError

# After
rescue SecID::InvalidFormatError
```

v5 adds two new exception types for more granular error handling:

- `SecID::InvalidCheckDigitError` — raised when check digit doesn't match
- `SecID::InvalidStructureError` — raised for type-specific structural errors (FIGI prefix, CFI category/group, IBAN BBAN, OCC date)

Both inherit from `SecID::Error`, so existing `rescue SecID::Error` blocks still work. Optionally catch the specific types:

```ruby
begin
  SecID::ISIN.new('US5949181040').validate!
rescue SecID::InvalidCheckDigitError => e
  # handle bad check digit specifically
rescue SecID::InvalidFormatError => e
  # handle format errors
end
```

### 10. Rename ValidationResult to Errors

`ValidationResult` has been renamed to `Errors`. The `valid?` method is replaced by `none?` for clearer semantics.

```ruby
# Before
result = SecId::ISIN.new('US5949181045').errors
result.valid?  # => true

# After
result = SecID::ISIN.new('US5949181045').errors
result.none?   # => true
```

Find all occurrences:

```bash
grep -rE 'ValidationResult|\.valid\?' app/ lib/ spec/
```

### 11. Update .validate usage (returns instance now)

`.validate` now returns the identifier instance (with errors cached) instead of a `ValidationResult`/`Errors` object.

```ruby
# Before (v4)
result = SecId::ISIN.validate('US5949181045')  # => #<SecId::ValidationResult>
result.valid?

# After (v5)
instance = SecID::ISIN.validate('US5949181045')  # => #<SecID::ISIN>
instance.errors.none?
```

### 12. Update subclass overrides (private API)

If you subclass `SecID::Base` and override private validation methods:

```ruby
# Before
def format_errors       # renamed
def validation_errors   # renamed

# After
def detect_errors
def error_codes
```

If you reference `EXCEPTION_MAP` or `exception_for_error`:

```ruby
# Before
Base::EXCEPTION_MAP
Klass.exception_for_error(:code)

# After
Validatable::ERROR_MAP
Klass.error_class_for(:code)
```

### 13. Explore new features (optional)

v5 adds several features beyond the breaking changes:

- **Structured validation** — `#errors` returns an `Errors` object with `details`, `messages`, `none?`, `any?`, `empty?`, `size`, `each`
- **Eager validation** — `#validate` / `.validate` triggers validation and returns the instance
- **Fail-fast validation** — `#validate!` raises descriptive exceptions
- **Type detection** — `SecID.detect('US5949181045')` returns `[:isin]`
- **Universal parsing** — `SecID.parse('US5949181045')` returns a typed instance
- **Quick validation** — `SecID.valid?('US5949181045')` validates against all types
- **Metadata registry** — `SecID.identifiers`, `SecID[:isin]`, `SecID::ISIN.full_name`
- **Universal normalization** — all types now support `#normalized`, `#normalize!`, `.normalize`

See [README.md](README.md) for full usage examples.
