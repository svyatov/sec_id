# Changelog

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
