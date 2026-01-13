# Changelog

## [Unreleased]

### Added

- LEI support (Legal Entity Identifier, ISO 17442)
- IBAN support (International Bank Account Number, ISO 13616) with EU/EEA country validation

### Updated

- Improved README: better formatting, navigation, and clear API distinction between check-digit and normalization identifiers

### Internal

- Refactored CIK and OCC to inherit from Base class with `has_check_digit?` hook for cleaner architecture
- Added `validate_format_for_calculation!` helper method to Base class to reduce code duplication
- Added comprehensive YARD documentation to Base class
- Created shared RSpec examples for edge cases (nil, empty, whitespace inputs)
- Created shared RSpec examples for check-digit and normalization identifiers
- Improved test maintainability with 466 tests covering all identifier types

## [4.2.0] - 2025-01-12

### Added

- OCC support ([@wtn](https://github.com/wtn), [#93](https://github.com/svyatov/sec_id/pull/93))

### Fixed

- CUSIP#cins? usage example in README ([@wtn](https://github.com/wtn), [#91](https://github.com/svyatov/sec_id/pull/91))

### Updated

- Separate CIK from Base for cleaner architecture ([@wtn](https://github.com/wtn), [#92](https://github.com/svyatov/sec_id/pull/92))
- Use rubocop-rspec plugin ([@wtn](https://github.com/wtn), [#90](https://github.com/svyatov/sec_id/pull/90))
- Replace CodeClimate with Codecov
- Add permissions to CI workflow
- Clean up gemspec: update description and simplify files list

## [4.1.0] - 2024-09-23

### Added

- FIGI support ([@wtn](https://github.com/wtn), [#84](https://github.com/svyatov/sec_id/pull/84))
- CIK support ([@wtn](https://github.com/wtn), [#85](https://github.com/svyatov/sec_id/pull/85))
- Convert between CUSIPs and ISINs ([@wtn](https://github.com/wtn), [#86](https://github.com/svyatov/sec_id/pull/86), [#88](https://github.com/svyatov/sec_id/pull/88))
- CINS check method for CUSIPs ([@wtn](https://github.com/wtn), [#87](https://github.com/svyatov/sec_id/pull/87))

### Updated

- Small internal refactorings

## [4.0.0] - 2024-07-09

### Breaking changes

- Minimum required Ruby version is 3.1 now
- Default repository branch renamed to `main`

### Updated

- Small internal refactorings
- TravisCI -> GitHub Actions
- Dropped tests for Ruby below 3.1
- Rubocop's Ruby target version changed to 3.1

## [3.0.0] - 2020-03-10

### Breaking changes

- Minimum required Ruby version is 2.5 now

### Updated

- Small internal refactorings
- TravisCI config updated: dropped Ruby 2.3 and 2.4, added Ruby 2.7
- Rubocop's Ruby target version changed to 2.5

## [2.0.0] - 2019-02-03

### Added

- SEDOL numbers support: `SecId::SEDOL`

### Updated

- **Breaking change**

    API for accessing full number is unified across all classes:

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

### Updated

- Char to digit conversion now uses precalculated tables instead of dynamic calculation for speed

## [1.0.0] - 2017-10-25

### Added

- ISIN numbers support: `SecId::ISIN`
