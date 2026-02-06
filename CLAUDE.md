# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

- **Run all tests**: `bundle exec rake spec` or `bundle exec rspec`
- **Run single test file**: `bundle exec rspec spec/sec_id/isin_spec.rb`
- **Run specific test**: `bundle exec rspec spec/sec_id/isin_spec.rb:42`
- **Run linter**: `bundle exec rake rubocop` or `bundle exec rubocop`
- **Safe auto-fix lint issues**: `bundle exec rubocop -a`
- **Auto-fix ALL lint issues (potentially unsafe)**: `bundle exec rubocop -A`
- **Run both lint and tests**: `bundle exec rake` (default task)
- **Run tests with coverage**: `COVERAGE=1 bundle exec rspec`
- **Install dependencies**: `bin/setup`
- **Interactive console**: `bin/console`

## Architecture

This is a Ruby gem for validating securities identification numbers (ISIN, CUSIP, CEI, SEDOL, FIGI, LEI, IBAN, CIK, OCC, WKN, Valoren, CFI, FISN).

### Class Hierarchy

All identifier classes inherit from `SecId::Base` (`lib/sec_id/base.rb`), which provides:
- Core API: `valid?`, `valid_format?`, `validate`, `validation_errors`
- Class-level convenience methods that delegate to instance methods
- `parse` helper method for extracting identifier components
- Class-level metadata methods: `short_name`, `full_name`, `id_length`, `example`, `has_check_digit?`, `has_normalization?`
- Private validation helpers: `format_errors`, `valid_length?`, `valid_characters?`, `validation_message`, `build_error`

Each identifier class defines these metadata constants:
- `FULL_NAME` — human-readable standard name (e.g. `"International Securities Identification Number"`)
- `ID_LENGTH` — fixed length or valid length range
- `EXAMPLE` — representative valid identifier string
- `VALID_CHARS_REGEX` — regex for valid character set (used by `format_errors` fallback)

Classes with check digits include the `Checkable` concern, which adds:
- `valid?` override that validates check digit
- `restore!`, `check_digit`, `calculate_check_digit` methods
- Character-to-digit conversion maps and Luhn algorithm variants
- Class-level `restore!` and `check_digit` methods

### Registry (`lib/sec_id.rb`)

Identifier classes auto-register via `Base.inherited`. Access them through:
- `SecId[:isin]` — look up class by symbol key (raises `ArgumentError` if unknown)
- `SecId.identifiers` — all registered classes in load order

### Concerns (`lib/sec_id/concerns/`)

#### Checkable (`checkable.rb`)

Provides check-digit validation and calculation for identifiers with check digits. Include this in classes that have a check digit (ISIN, CUSIP, SEDOL, FIGI, LEI, IBAN, CEI).

Constants:
- `CHAR_TO_DIGITS` - Multi-digit mapping for ISIN (letters expand to two digits)
- `CHAR_TO_DIGIT` - Single-digit mapping (A=10, B=11, ..., Z=35)

Luhn algorithm variants:
- `luhn_sum_double_add_double(digits)` - Used by CUSIP and CEI
- `luhn_sum_indexed(digits)` - Used by FIGI
- `luhn_sum_standard(digits)` - Used by ISIN
- `reversed_digits_single(id)` - Converts identifier to reversed digit array (single-digit mapping)
- `reversed_digits_multi(id)` - Converts identifier to reversed digit array (multi-digit mapping for ISIN)

Validation overrides:
- `validation_errors` - Returns `[:invalid_check_digit]` when format is valid but check digit doesn't match
- `check_digit_width` - Returns `1` (used by `Base#valid_length?` to allow optional check digit in length check)

Helper methods:
- `mod10`, `div10mod10`, `mod97` - Check digit calculation helpers
- `char_to_digit`, `char_to_digits` - Character conversion helpers
- `validate_format_for_calculation!` - Raises error if format invalid

#### Normalizable (`normalizable.rb`)

Provides `normalize!` class method delegation for identifiers that support normalization (CIK, OCC, Valoren)

### Identifier Classes

Each identifier type (`lib/sec_id/*.rb`) implements:
- `ID_REGEX` constant with named capture groups for parsing
- `initialize` that calls `parse` and extracts components
- Type-specific attributes (e.g., `country_code`, `nsin` for ISIN; `cusip6`, `issue` for CUSIP)

**Classes with check digits** (ISIN, CUSIP, SEDOL, FIGI, LEI, IBAN, CEI):
- Include `Checkable` concern
- Implement `calculate_check_digit` with standard-specific algorithm
- LEI overrides `check_digit_width` → `2` (two-character check digit)

**Classes without check digits** (CIK, OCC, WKN, Valoren, CFI, FISN):
- Do not include `Checkable`
- Validation based solely on format

**Type-specific validation overrides:**
- FIGI: `format_errors` returns `:invalid_prefix` for restricted prefixes (BS, BM, GG, GB, GH, KY, VG)
- CFI: `format_errors` returns `:invalid_category` and/or `:invalid_group` for unrecognized codes
- IBAN: `format_errors` returns `:invalid_bban` when BBAN format doesn't match country rules
- OCC: `validation_errors` returns `:invalid_date` when date string can't be parsed

### Conversion Methods

- `ISIN#to_cusip` - Convert ISIN to CUSIP (for CGS country codes only)
- `ISIN#to_sedol` - Convert ISIN to SEDOL (for GB, IE, GG, IM, JE country codes)
- `ISIN#to_wkn` - Convert ISIN to WKN (for DE country code)
- `ISIN#to_valoren` - Convert ISIN to Valoren (for CH/LI country codes)
- `CUSIP#to_isin(country_code)` - Convert CUSIP to ISIN
- `SEDOL#to_isin(country_code = 'GB')` - Convert SEDOL to ISIN (supports GB, IE, GG, IM, JE)
- `WKN#to_isin(country_code = 'DE')` - Convert WKN to ISIN
- `Valoren#to_isin(country_code = 'CH')` - Convert Valoren to ISIN (supports CH, LI)

### ValidationResult (`lib/sec_id/validation_result.rb`)

Frozen, immutable value object returned by `#validate`. Contains:
- `errors` — array of `{ code: Symbol, message: String }` hashes (frozen)
- `valid?` — true when errors empty
- `error_codes` — maps errors to just code symbols
- `to_a` — aliases to `errors`

### Error Handling

- `SecId::Error` - Base error class
- `SecId::InvalidFormatError` - Raised when check-digit calculation fails on invalid format
- **Important:** Classes that include `Checkable` must implement `calculate_check_digit`. If `NotImplementedError` is raised from a concrete identifier class, it indicates a missing implementation.

## Code Style

- Ruby 3.1+ required
- Max line length: 120 characters
- RuboCop with rubocop-rspec extension
- RSpec with `expect` syntax only (no monkey patching)

### Method Ordering (Stepdown Rule)

Follow the "Stepdown Rule" from Clean Code: methods should be ordered so that callers appear before callees. Code should read top-to-bottom like a newspaper article—high-level concepts first, implementation details below.

```ruby
# Good - caller before callee, reads top-to-bottom
def validate
  check_format
  check_digit_valid?
end

def check_format
  parse_components
end

def check_digit_valid?
  # ...
end

def parse_components
  # ...
end

# Bad - callees appear before callers
def parse_components
  # ...
end

def check_format
  parse_components
end

def validate
  check_format
  check_digit_valid?
end
```

## Commit Message Convention

This project follows [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

Format: `<type>[optional scope]: <description>`

### Types

| Type | Description | Version bump |
|------|-------------|--------------|
| `feat` | New feature | MINOR |
| `fix` | Bug fix | PATCH |
| `docs` | Documentation only | — |
| `style` | Formatting, whitespace | — |
| `refactor` | Code change (no feature/fix) | — |
| `perf` | Performance improvement | — |
| `test` | Adding/fixing tests | — |
| `build` | Build system or dependencies | — |
| `ci` | CI configuration | — |
| `chore` | Maintenance tasks | — |

### Breaking Changes

Use `!` after type or add `BREAKING CHANGE:` footer. Breaking changes trigger a MAJOR version bump.

### Examples

```
feat: add WKN support
fix: correct CUSIP check-digit for alphanumeric input
docs: update README with LEI usage examples
refactor: extract shared Normalizable module
feat!: rename full_number to identifier across all classes
chore: bump version to 4.4.0
```

## Changelog Format

This project follows [Keep a Changelog v1.1.0](https://keepachangelog.com/en/1.1.0/).

Allowed categories in **required order**:

1. **Added** — new features
2. **Changed** — changes to existing functionality
3. **Deprecated** — soon-to-be removed features
4. **Removed** — removed features
5. **Fixed** — bug fixes
6. **Security** — vulnerability fixes

Rules:
- Categories must appear in the order listed above within each release section
- Each category must appear **at most once** per release section — always append to an existing category rather than creating a duplicate
- Do NOT use non-standard categories like "Updated", "Internal", or "Breaking changes"
- Breaking changes should be prefixed with **BREAKING:** within the relevant category (typically Changed or Removed)

## Documentation Style

All classes and methods must have YARD documentation. Follow these conventions:

- Always leave a **blank line** between the main description and `@` attributes (params, return, etc.)
- Document all public methods with description, params, and return types
- Document all private methods with params and return types, add description for complex logic
- Include `@example` blocks for non-obvious usage patterns
- Use `@raise` to document exceptions
- **Omit descriptions that just repeat the code** - if the method name and signature make it obvious, only include `@param`, `@return`, and `@raise` tags without a description

```ruby
# Good - blank line before @param
# Calculates the check digit for this identifier.
#
# @param value [String] the value to calculate
# @return [Integer] the calculated check digit
def calculate_check_digit(value)
end

# Bad - no blank line
# Calculates the check digit for this identifier.
# @param value [String] the value to calculate
# @return [Integer] the calculated check digit
def calculate_check_digit(value)
end
```

## Pre-Commit Checklist

Before committing changes, always verify these files are updated to accurately reflect the changes:

- **CLAUDE.md** - Update this file
- **README.md** - Update usage examples, Table of Contents, and supported standards list
- **CHANGELOG.md** - Add entry under `[Unreleased]` section describing the change (use only standard Keep a Changelog categories — see Changelog Format section above)
- **sec_id.gemspec** - Update `description` if adding/removing supported standards

## Releasing a New Version

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):
- **MAJOR** — breaking changes (incompatible API changes)
- **MINOR** — new features (backwards-compatible)
- **PATCH** — bug fixes (backwards-compatible)

1. Update `lib/sec_id/version.rb` with the new version number
2. Update `CHANGELOG.md`: change `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD` and add new empty `[Unreleased]` section
3. Update `README.md` installation version if needed (e.g., `~> 4.3` to `~> 4.4`)
4. Commit changes: `git commit -am "chore: bump version to X.Y.Z"`
5. Release: `bundle exec rake release` - this will:
   - Build the gem
   - Create and push the git tag
   - Push the gem to RubyGems.org (requires OTP if MFA enabled)
6. Create GitHub release at https://github.com/svyatov/sec_id/releases with notes from CHANGELOG
