# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

- **Run all tests**: `rake spec` or `bundle exec rspec`
- **Run single test file**: `bundle exec rspec spec/sec_id/isin_spec.rb`
- **Run specific test**: `bundle exec rspec spec/sec_id/isin_spec.rb:42`
- **Run linter**: `rake rubocop` or `bundle exec rubocop`
- **Auto-fix lint issues**: `bundle exec rubocop -a`
- **Run both lint and tests**: `rake` (default task)
- **Run tests with coverage**: `COVERAGE=1 bundle exec rspec`
- **Install dependencies**: `bin/setup` or `bundle install`
- **Interactive console**: `bin/console`

## Architecture

This is a Ruby gem for validating securities identification numbers (ISIN, CUSIP, SEDOL, FIGI, CIK, OCC).

### Class Hierarchy

All identifier classes inherit from `SecId::Base` (`lib/sec_id/base.rb`), which provides:
- Core API: `valid?`, `valid_format?`, `restore!`, `check_digit`/`calculate_check_digit`
- Class-level convenience methods that delegate to instance methods
- Character-to-digit conversion maps (`CHAR_TO_DIGITS`, `CHAR_TO_DIGIT`) for check-digit algorithms
- Helper methods: `mod10`, `div10mod10`, `parse`

### Identifier Classes

Each identifier type (`lib/sec_id/*.rb`) implements:
- `ID_REGEX` constant with named capture groups for parsing
- `initialize` that calls `parse` and extracts components
- `calculate_check_digit` with standard-specific algorithm (usually Luhn variant)
- Type-specific attributes (e.g., `country_code`, `nsin` for ISIN; `cusip6`, `issue` for CUSIP)

### Conversion Methods

- `ISIN#to_cusip` - Convert ISIN to CUSIP (for CGS country codes only)
- `CUSIP#to_isin(country_code)` - Convert CUSIP to ISIN

### Error Handling

- `SecId::Error` - Base error class
- `SecId::InvalidFormatError` - Raised when check-digit calculation fails on invalid format

## Code Style

- Ruby 3.1+ required
- Max line length: 120 characters
- RuboCop with rubocop-rspec extension
- RSpec with `expect` syntax only (no monkey patching)
