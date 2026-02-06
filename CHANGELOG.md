# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## [Unreleased]

### Added

- Rails-like `#errors` API returning `ValidationResult` with `details`, `messages`, `any?`, `empty?`, `size`, `valid?`, and `to_a` on all identifier classes, with type-specific error detection for check digits, FIGI prefixes, CFI categories/groups, IBAN BBAN format, and OCC dates
- Metadata registry: `SecId.identifiers` returns all identifier classes, `SecId[:isin]` looks up by symbol key
- Metadata class methods on all identifiers: `short_name`, `full_name`, `id_length`, `example`, `has_check_digit?`, `has_normalization?`
### Changed

- **BREAKING:** `#validate` renamed to `#errors` (memoized); class-level `.validate` still available
- **BREAKING:** `ValidationResult#errors` renamed to `#details`; each hash uses `:error` key instead of `:code`
- **BREAKING:** `ValidationResult#error_codes` removed; use `details.map { |d| d[:error] }`
- **BREAKING:** `ValidationResult#to_a` now returns `messages` (array of strings) instead of raw error hashes
- **BREAKING:** `#validation_errors` and `.validation_errors` removed from public API

### Removed

- `#valid_format?` instance method (now private) and `.valid_format?` class method
- `#valid_check_digit?` instance method and `.valid_check_digit?` class method
- `#validation_errors` instance method (now private)
- `.validation_errors` class method

### Fixed

- OCC `ID_LENGTH` changed from `21` to `(16..21)` to correctly reflect that valid OCC symbols range from 16 to 21 characters

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

- SEDOL numbers support: `SecId::SEDOL`

### Changed

- **BREAKING:** API for accessing full number is unified across all classes:

    ```
    SecId::ISIN#full_number  # previously SecId::ISIN#isin
    SecId::CUSIP#full_number # previously SecId::CUSIP#cusip
    SecId::SEDOL#full_number
    ```

### Fixed

- CUSIP check-digit algorithm fixed

## [1.1.0] - 2019-02-03

### Added

- CUSIP numbers support: `SecId::CUSIP`
- CHANGELOG.md file added

### Changed

- Char to digit conversion now uses precalculated tables instead of dynamic calculation for speed

## [1.0.0] - 2017-10-25

### Added

- ISIN numbers support: `SecId::ISIN`
