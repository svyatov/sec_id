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
SecID::CIK.normalize!('1094517')

# After
SecID::CIK.normalize('1094517')   # => '0001094517'
```

Note: In v5, all identifier types support normalization, not just CIK/OCC/Valoren.

### 6. Remove calls to deleted methods

**`valid_format?` / `.valid_format?`** — removed from public API. Use `valid?` for boolean checks or `errors` for details:

```ruby
# Before
SecID::ISIN.valid_format?('US5949181045')

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
result = SecID::ISIN.new('US5949181045').errors
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
result = SecID::ISIN.validate('US5949181045')  # => #<SecID::ValidationResult>
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
