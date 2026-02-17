# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## [Unreleased]

### Added

- `#restore` instance method on check-digit identifiers returning the full identifier string without mutation
- `.restore` class method on check-digit identifiers returning the full identifier string
- `SecID.parse(str, types: nil)` and `SecID.parse!(str, types: nil)` methods that return a typed identifier instance for the most specific match, with optional type filtering
- `SecID.valid?(str, types: nil)` method for quick boolean validation against all or specific identifier types
- `SecID.detect(str)` method that identifies all matching identifier types for a given string, returning symbols sorted by specificity
- `#validate!` and `.validate!` methods that raise `InvalidFormatError`, `InvalidCheckDigitError`, or `InvalidStructureError` on validation failure, returning self/instance on success
- Rails-like `#errors` API returning `ValidationResult` with `details`, `messages`, `any?`, `empty?`, `size`, `valid?`, and `to_a` on all identifier classes, with type-specific error detection for check digits, FIGI prefixes, CFI categories/groups, IBAN BBAN format, and OCC dates
- Metadata registry: `SecID.identifiers` returns all identifier classes, `SecID[:isin]` looks up by symbol key
- Metadata class methods on all identifiers: `short_name`, `full_name`, `id_length`, `example`, `has_check_digit?`
- `#normalized` and `#normalize` instance methods on all identifier types returning the canonical string form
- `#normalize!` instance method on all identifier types that mutates `full_id` to canonical form and returns `self`
- `.normalize(id)` class method on all identifier types that strips separators, upcases, validates, and returns the canonical string
- `SEPARATORS` constant on `Base` (`/[\s-]/`) with type-specific overrides for OCC and FISN (`/-/`)

### Changed

- **BREAKING:** Minimum Ruby version raised from 3.1 to 3.2 (Ruby 3.1 reached EOL on 2025-03-31)
- **BREAKING:** `#restore!` now returns `self` instead of a string; use `#restore` for the string return value
- **BREAKING:** `.restore!` now returns the restored instance instead of a string; use `.restore` for the string return value
- **BREAKING:** `#normalize!` on CIK, OCC, and Valoren now returns `self` instead of a string; use `#normalized` to get the canonical string
- **BREAKING:** Class-level `.normalize!` on CIK, OCC, and Valoren replaced by `.normalize` (non-bang) which returns the canonical string
- **BREAKING:** `Base#parse` always upcases input; the `upcase` keyword parameter is removed
- **BREAKING:** `#full_number` renamed to `#full_id` on all identifier types
- **BREAKING:** Ruby module renamed from `SecId` to `SecID` (e.g. `SecId::ISIN` → `SecID::ISIN`)
- Luhn helper methods in Checkable are now private (implementation detail)

### Removed

- `Normalizable` concern (`lib/sec_id/concerns/normalizable.rb`) — normalization is now built into `Base`
- Class-level `.normalize!` on CIK, OCC, and Valoren — replaced by `.normalize`
- `upcase` keyword parameter from `Base#parse`
- `#valid_format?` instance method (now private) and `.valid_format?` class method
- `OCC#full_symbol` method — use `#full_id` instead

### Fixed

- `to_str` now always returns the same value as `to_s` across all identifier types — previously LEI, IBAN, and Checkable identifiers could return divergent strings due to Ruby `alias` resolving to the parent class method
- OCC `#date` memoization for invalid dates — previously re-attempted parsing on every call instead of caching `nil`
- LEI `restore` and `to_s` now correctly pad single-digit check digits to 2 characters
- CUSIP and SEDOL `to_isin` now always embed the correct check digit

## [4.4.1] - 2026-02-05

### Fixed

- `CUSIP#to_isin` and `SEDOL#to_isin` no longer mutate source instance when check digit is missing ([#127](https://github.com/svyatov/sec_id/issues/127))

## [4.4.0] - 2026-01-29

### Added

- Cross-identifier conversions: SEDOL, WKN, and Valoren `to_isin` methods with country code validation; ISIN `to_sedol`, `to_wkn`, `to_valoren` methods with predicate helpers (`sedol?`, `wkn?`, `valoren?`) ([#115](https://github.com/svyatov/sec_id/pull/115))
- ISIN `nsin_type` and `to_nsin` methods for country-aware NSIN extraction ([#114](https://github.com/svyatov/sec_id/pull/114))
- CEI (CUSIP Entity Identifier) support for syndicated loan market entity identification ([#113](https://github.com/svyatov/sec_id/pull/113))
- FISN (Financial Instrument Short Name) support per ISO 18774 ([#112](https://github.com/svyatov/sec_id/pull/112))
- CFI (Classification of Financial Instruments) support with category/group validation and equity-specific predicates ([#111](https://github.com/svyatov/sec_id/pull/111))
- Valoren support (Swiss Security Number) ([@wtn](https://github.com/wtn), [#109](https://github.com/svyatov/sec_id/pull/109))
- WKN support (Wertpapierkennnummer - German securities identifier) ([@wtn](https://github.com/wtn), [#108](https://github.com/svyatov/sec_id/pull/108))

### Changed

- Replaced `has_check_digit` DSL with explicit `Checkable` concern that consolidates all check-digit logic (constants, Luhn algorithms, validation, restoration)
- Simplified `Base` class to core validation and parsing; check-digit classes now `include Checkable`
- Non-check-digit classes (CIK, OCC, WKN, Valoren, CFI, FISN) no longer need any special declaration
- Moved `Normalizable` module to `lib/sec_id/concerns/` for consistency with other concerns
- Optimized hot paths by replacing `&method(:char_to_digit)` with inline blocks to avoid Method object allocation
- Added frozen Set constants for ISIN country code lookups (`SEDOL_COUNTRY_CODES`, `VALOREN_COUNTRY_CODES`)

### Fixed

- Allow Crown Dependencies (GG, IM, JE) and Overseas Territories (FK) in SEDOL/ISIN conversions ([@wtn](https://github.com/wtn), [#117](https://github.com/svyatov/sec_id/pull/117))
- Removed BR (Brazil) from CGS country codes — Brazil never used CINS numbers and Brazilian ISINs cannot be converted to CUSIP ([@wtn](https://github.com/wtn), [#110](https://github.com/svyatov/sec_id/pull/110))

## [4.3.0] - 2025-01-13

### Added

- LEI support (Legal Entity Identifier, ISO 17442)
- IBAN support (International Bank Account Number, ISO 13616) with EU/EEA country validation

### Changed

- Improved README: better formatting, navigation, and clear API distinction between check-digit and normalization identifiers
- Refactored CIK and OCC to inherit from Base class with `has_check_digit?` hook for cleaner architecture
- Added `Normalizable` module for consistent `normalize!` class method across identifiers
- Added `validate_format_for_calculation!` helper method to Base class to reduce code duplication
- Added comprehensive YARD documentation to all classes (public and private methods)
- Applied Stepdown Rule to method ordering throughout codebase
- Created shared RSpec examples for edge cases (nil, empty, whitespace inputs)
- Created shared RSpec examples for check-digit and normalization identifiers
- Applied shared examples to all identifier specs, removing ~350 lines of duplicate test code
- Improved test maintainability with 582 tests covering all identifier types

## [4.2.0] - 2025-01-12

### Added

- OCC support ([@wtn](https://github.com/wtn), [#93](https://github.com/svyatov/sec_id/pull/93))

### Changed

- Separate CIK from Base for cleaner architecture ([@wtn](https://github.com/wtn), [#92](https://github.com/svyatov/sec_id/pull/92))
- Use rubocop-rspec plugin ([@wtn](https://github.com/wtn), [#90](https://github.com/svyatov/sec_id/pull/90))
- Replace CodeClimate with Codecov
- Add permissions to CI workflow
- Clean up gemspec: update description and simplify files list

### Fixed

- CUSIP#cins? usage example in README ([@wtn](https://github.com/wtn), [#91](https://github.com/svyatov/sec_id/pull/91))

## [4.1.0] - 2024-09-23

### Added

- FIGI support ([@wtn](https://github.com/wtn), [#84](https://github.com/svyatov/sec_id/pull/84))
- CIK support ([@wtn](https://github.com/wtn), [#85](https://github.com/svyatov/sec_id/pull/85))
- Convert between CUSIPs and ISINs ([@wtn](https://github.com/wtn), [#86](https://github.com/svyatov/sec_id/pull/86), [#88](https://github.com/svyatov/sec_id/pull/88))
- CINS check method for CUSIPs ([@wtn](https://github.com/wtn), [#87](https://github.com/svyatov/sec_id/pull/87))

### Changed

- Small internal refactorings

## [4.0.0] - 2024-07-09

### Changed

- **BREAKING:** Minimum required Ruby version is 3.1 now
- **BREAKING:** Default repository branch renamed to `main`
- Small internal refactorings
- TravisCI -> GitHub Actions
- Dropped tests for Ruby below 3.1
- Rubocop's Ruby target version changed to 3.1

## [3.0.0] - 2020-03-10

### Changed

- **BREAKING:** Minimum required Ruby version is 2.5 now
- Small internal refactorings
- TravisCI config updated: dropped Ruby 2.3 and 2.4, added Ruby 2.7
- Rubocop's Ruby target version changed to 2.5

## [2.0.0] - 2019-02-03

### Added

- SEDOL numbers support: `SecID::SEDOL`

### Changed

- **BREAKING:** API for accessing full number is unified across all classes:

    ```
    SecID::ISIN#full_id  # previously SecID::ISIN#isin
    SecID::CUSIP#full_id # previously SecID::CUSIP#cusip
    SecID::SEDOL#full_id
    ```

### Fixed

- CUSIP check-digit algorithm fixed

## [1.1.0] - 2019-02-03

### Added

- CUSIP numbers support: `SecID::CUSIP`
- CHANGELOG.md file added

### Changed

- Char to digit conversion now uses precalculated tables instead of dynamic calculation for speed

## [1.0.0] - 2017-10-25

### Added

- ISIN numbers support: `SecID::ISIN`
