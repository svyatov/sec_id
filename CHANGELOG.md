# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## [Unreleased]

### Added

- Cross-identifier conversions: SEDOL, WKN, and Valoren `to_isin` methods with country code validation; ISIN `to_sedol`, `to_wkn`, `to_valoren` methods with predicate helpers (`sedol?`, `wkn?`, `valoren?`) ([#115](https://github.com/svyatov/sec_id/pull/115))
- ISIN `nsin_type` and `to_nsin` methods for country-aware NSIN extraction ([#114](https://github.com/svyatov/sec_id/pull/114))
- CEI (CUSIP Entity Identifier) support for syndicated loan market entity identification ([#113](https://github.com/svyatov/sec_id/pull/113))
- FISN (Financial Instrument Short Name) support per ISO 18774 ([#112](https://github.com/svyatov/sec_id/pull/112))
- CFI (Classification of Financial Instruments) support with category/group validation and equity-specific predicates ([#111](https://github.com/svyatov/sec_id/pull/111))
- Valoren support (Swiss Security Number) ([@wtn](https://github.com/wtn), [#109](https://github.com/svyatov/sec_id/pull/109))
- WKN support (Wertpapierkennnummer - German securities identifier) ([@wtn](https://github.com/wtn), [#108](https://github.com/svyatov/sec_id/pull/108))

### Changed

- Extracted shared Luhn algorithm variants into `CheckDigitAlgorithms` concern for DRY check-digit calculations across CUSIP, CEI, FIGI, and ISIN
- Moved `Normalizable` module to `lib/sec_id/concerns/` for consistency with other concerns
- Added `has_check_digit` DSL to Base class for declaring identifier check-digit behavior, replacing boilerplate `has_check_digit?` method overrides
- Optimized hot paths by replacing `&method(:char_to_digit)` with inline blocks to avoid Method object allocation
- Added frozen Set constants for ISIN country code lookups (`SEDOL_COUNTRY_CODES`, `VALOREN_COUNTRY_CODES`)

### Fixed

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
