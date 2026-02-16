# SecId [![Gem Version](https://img.shields.io/gem/v/sec_id)](https://rubygems.org/gems/sec_id) [![Codecov](https://img.shields.io/codecov/c/github/svyatov/sec_id)](https://app.codecov.io/gh/svyatov/sec_id) [![CI](https://github.com/svyatov/sec_id/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/svyatov/sec_id/actions?query=workflow%3ACI)

> Validate securities identification numbers with ease!

## Table of Contents

- [Supported Ruby Versions](#supported-ruby-versions)
- [Installation](#installation)
- [Supported Standards and Usage](#supported-standards-and-usage)
  - [Metadata Registry](#metadata-registry) - enumerate, filter, look up, and detect identifier types
  - [Structured Validation](#structured-validation) - detailed error codes and messages
  - [ISIN](#isin) - International Securities Identification Number
  - [CUSIP](#cusip) - Committee on Uniform Securities Identification Procedures
  - [CEI](#cei) - CUSIP Entity Identifier
  - [SEDOL](#sedol) - Stock Exchange Daily Official List
  - [FIGI](#figi) - Financial Instrument Global Identifier
  - [LEI](#lei) - Legal Entity Identifier
  - [IBAN](#iban) - International Bank Account Number
  - [CIK](#cik) - Central Index Key
  - [OCC](#occ) - Options Clearing Corporation Symbol
  - [WKN](#wkn) - Wertpapierkennnummer
  - [Valoren](#valoren) - Swiss Security Number
  - [CFI](#cfi) - Classification of Financial Instruments
  - [FISN](#fisn) - Financial Instrument Short Name
- [Development](#development)
- [Contributing](#contributing)
- [Changelog](#changelog)
- [Versioning](#versioning)
- [License](#license)

## Supported Ruby Versions

Ruby 3.1+ is required.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sec_id', '~> 5.0'
```

And then execute:

```bash
bundle install
```

Or install it yourself:

```bash
gem install sec_id
```

## Supported Standards and Usage

All identifier classes provide `valid?`, `errors`, `validate!`, and `.validate` methods at both class and instance levels.

**All identifiers** support normalization:
- `.normalize(id)` - strips separators, upcases, validates, and returns the canonical string
- `#normalized` / `#normalize` - returns the canonical string for a valid instance
- `#normalize!` - mutates `full_id` to canonical form, returns `self`

**Check-digit based identifiers** (ISIN, CUSIP, CEI, SEDOL, FIGI, LEI, IBAN) also provide:
- `restore` / `.restore` - returns the full identifier string with correct check-digit (no mutation)
- `restore!` / `.restore!` - restores check-digit in place and returns `self` / instance
- `check_digit` / `calculate_check_digit` - calculates and returns the check-digit

### Metadata Registry

All identifier classes are registered automatically and can be enumerated, filtered, and looked up by symbol key:

```ruby
# Look up by symbol key
SecId[:isin]                              # => SecId::ISIN
SecId[:cusip]                             # => SecId::CUSIP

# Enumerate all identifier classes
SecId.identifiers                         # => [SecId::ISIN, SecId::CUSIP, ...]
SecId.identifiers.map(&:short_name)       # => ["ISIN", "CUSIP", "SEDOL", ...]

# Query metadata
SecId::ISIN.short_name                    # => "ISIN"
SecId::ISIN.full_name                     # => "International Securities Identification Number"
SecId::ISIN.id_length                     # => 12
SecId::ISIN.example                       # => "US5949181045"
SecId::ISIN.has_check_digit?              # => true

# Filter with standard Ruby
SecId.identifiers.select(&:has_check_digit?).map(&:short_name)
# => ["ISIN", "CUSIP", "SEDOL", "FIGI", "LEI", "IBAN", "CEI"]

# Detect identifier type from an unknown string
# Results are sorted by specificity: check-digit types first, then by length precision
SecId.detect('US5949181045')  # => [:isin]
SecId.detect('037833100')     # => [:cusip, :valoren, :cik]
SecId.detect('APPLE INC/SH')  # => [:fisn]
SecId.detect('INVALID')       # => []

# Quick boolean validation
SecId.valid?('US5949181045')                      # => true (any type)
SecId.valid?('INVALID')                           # => false
SecId.valid?('US5949181045', types: [:isin])      # => true
SecId.valid?('594918104', types: %i[cusip sedol]) # => true
SecId.valid?('US5949181045', types: [:cusip])     # => false

# Parse into a typed instance (returns the most specific match)
SecId.parse('US5949181045')                       # => #<SecId::ISIN>
SecId.parse('594918104')                          # => #<SecId::CUSIP>
SecId.parse('unknown')                            # => nil
SecId.parse('594918104', types: [:cusip])         # => #<SecId::CUSIP>

# Bang version raises on failure
SecId.parse!('US5949181045')                      # => #<SecId::ISIN>
SecId.parse!('unknown')                           # raises SecId::InvalidFormatError
```

### Structured Validation

All identifier classes provide a Rails-like `#errors` API for detailed error reporting:

```ruby
isin = SecId::ISIN.new('US5949181040')
isin.errors.valid?    # => false
isin.errors.messages  # => ["Check digit '0' is invalid, expected '5'"]
isin.errors.details   # => [{ error: :invalid_check_digit, message: "Check digit '0' is invalid, expected '5'" }]
isin.errors.any?      # => true
isin.errors.empty?    # => false
isin.errors.size      # => 1
isin.errors.to_a      # => same as messages

# Class-level convenience method
SecId::ISIN.validate('US5949181040')  # => #<SecId::ValidationResult>
```

**Common error codes** (all identifier types):
- `:invalid_length` - wrong number of characters
- `:invalid_characters` - contains characters not allowed for this type
- `:invalid_format` - correct length and characters but wrong structure

**Type-specific error codes:**
- `:invalid_check_digit` - check digit mismatch (ISIN, CUSIP, SEDOL, FIGI, LEI, IBAN, CEI)
- `:invalid_prefix` - restricted FIGI prefix (FIGI)
- `:invalid_category` - unknown CFI category code (CFI)
- `:invalid_group` - unknown CFI group code for category (CFI)
- `:invalid_bban` - BBAN format invalid for country (IBAN)
- `:invalid_date` - unparseable expiration date (OCC)

#### Fail-fast validation with `validate!`

Use `validate!` when you want to raise an exception on invalid input instead of inspecting errors:

```ruby
# Returns self when valid (enables chaining)
SecId::ISIN.new('US5949181045').validate!  # => #<SecId::ISIN>

# Raises with a descriptive message when invalid
SecId::ISIN.new('INVALID').validate!
# => SecId::InvalidFormatError: Expected 12 characters, got 7

SecId::ISIN.new('US5949181040').validate!
# => SecId::InvalidCheckDigitError: Check digit '0' is invalid, expected '5'

SecId::FIGI.new('BSG000BLNNH6').validate!
# => SecId::InvalidStructureError: Prefix 'BS' is restricted

# Class-level convenience method (returns the instance)
isin = SecId::ISIN.validate!('US5949181045')  # => #<SecId::ISIN>
```

### ISIN

> [International Securities Identification Number](https://en.wikipedia.org/wiki/International_Securities_Identification_Number) - a 12-character alphanumeric code that uniquely identifies a security.

```ruby
# class level
SecId::ISIN.valid?('US5949181045')      # => true
SecId::ISIN.restore('US594918104')      # => 'US5949181045'
SecId::ISIN.restore!('US594918104')     # => #<SecId::ISIN>
SecId::ISIN.check_digit('US594918104')  # => 5

# instance level
isin = SecId::ISIN.new('US5949181045')
isin.full_id               # => 'US5949181045'
isin.country_code          # => 'US'
isin.nsin                  # => '594918104'
isin.check_digit           # => 5
isin.valid?                # => true
isin.restore               # => 'US5949181045'
isin.restore!              # => #<SecId::ISIN> (mutates instance)
isin.calculate_check_digit # => 5
isin.to_cusip              # => #<SecId::CUSIP>
isin.nsin_type             # => :cusip
isin.to_nsin               # => #<SecId::CUSIP>

# NSIN extraction for different countries
SecId::ISIN.new('GB00B02H2F76').nsin_type  # => :sedol
SecId::ISIN.new('GB00B02H2F76').to_nsin    # => #<SecId::SEDOL>
SecId::ISIN.new('DE0007164600').nsin_type  # => :wkn
SecId::ISIN.new('DE0007164600').to_nsin    # => #<SecId::WKN>
SecId::ISIN.new('CH0012221716').nsin_type  # => :valoren
SecId::ISIN.new('CH0012221716').to_nsin    # => #<SecId::Valoren>
SecId::ISIN.new('FR0000120271').nsin_type  # => :generic
SecId::ISIN.new('FR0000120271').to_nsin    # => '000012027' (raw NSIN string)

# Type-specific conversion methods with validation
SecId::ISIN.new('GB00B02H2F76').sedol?     # => true
SecId::ISIN.new('GB00B02H2F76').to_sedol   # => #<SecId::SEDOL>
SecId::ISIN.new('DE0007164600').wkn?       # => true
SecId::ISIN.new('DE0007164600').to_wkn     # => #<SecId::WKN>
SecId::ISIN.new('CH0012221716').valoren?   # => true
SecId::ISIN.new('CH0012221716').to_valoren # => #<SecId::Valoren>
```

### CUSIP

> [Committee on Uniform Securities Identification Procedures](https://en.wikipedia.org/wiki/CUSIP) - a 9-character alphanumeric code that identifies North American securities.

```ruby
# class level
SecId::CUSIP.valid?('594918104')      # => true
SecId::CUSIP.restore('59491810')      # => '594918104'
SecId::CUSIP.restore!('59491810')     # => #<SecId::CUSIP>
SecId::CUSIP.check_digit('59491810')  # => 4

# instance level
cusip = SecId::CUSIP.new('594918104')
cusip.full_id               # => '594918104'
cusip.cusip6                # => '594918'
cusip.issue                 # => '10'
cusip.check_digit           # => 4
cusip.valid?                # => true
cusip.restore               # => '594918104'
cusip.restore!              # => #<SecId::CUSIP> (mutates instance)
cusip.calculate_check_digit # => 4
cusip.to_isin('US')         # => #<SecId::ISIN>
cusip.cins?                 # => false
```

### CEI

> [CUSIP Entity Identifier](https://www.cusip.com/identifiers.html) - a 10-character alphanumeric code that identifies legal entities in the syndicated loan market.

```ruby
# class level
SecId::CEI.valid?('A0BCDEFGH1')      # => true
SecId::CEI.restore('A0BCDEFGH')      # => 'A0BCDEFGH1'
SecId::CEI.restore!('A0BCDEFGH')     # => #<SecId::CEI>
SecId::CEI.check_digit('A0BCDEFGH')  # => 1

# instance level
cei = SecId::CEI.new('A0BCDEFGH1')
cei.full_id               # => 'A0BCDEFGH1'
cei.prefix                # => 'A'
cei.numeric               # => '0'
cei.entity_id             # => 'BCDEFGH'
cei.check_digit           # => 1
cei.valid?                # => true
cei.restore               # => 'A0BCDEFGH1'
cei.restore!              # => #<SecId::CEI> (mutates instance)
cei.calculate_check_digit # => 1
```

### SEDOL

> [Stock Exchange Daily Official List](https://en.wikipedia.org/wiki/SEDOL) - a 7-character alphanumeric code used in the United Kingdom, Ireland, Crown Dependencies (Jersey, Guernsey, Isle of Man), and select British Overseas Territories.

```ruby
# class level
SecId::SEDOL.valid?('B0Z52W5')      # => true
SecId::SEDOL.restore('B0Z52W')      # => 'B0Z52W5'
SecId::SEDOL.restore!('B0Z52W')     # => #<SecId::SEDOL>
SecId::SEDOL.check_digit('B0Z52W')  # => 5

# instance level
sedol = SecId::SEDOL.new('B0Z52W5')
sedol.full_id               # => 'B0Z52W5'
sedol.check_digit           # => 5
sedol.valid?                # => true
sedol.restore               # => 'B0Z52W5'
sedol.restore!              # => #<SecId::SEDOL> (mutates instance)
sedol.calculate_check_digit # => 5
sedol.to_isin               # => #<SecId::ISIN> (GB ISIN by default)
sedol.to_isin('IE')         # => #<SecId::ISIN> (IE ISIN)
```

### FIGI

> [Financial Instrument Global Identifier](https://en.wikipedia.org/wiki/Financial_Instrument_Global_Identifier) - a 12-character alphanumeric code that provides unique identification of financial instruments.

```ruby
# class level
SecId::FIGI.valid?('BBG000DMBXR2')     # => true
SecId::FIGI.restore('BBG000DMBXR')     # => 'BBG000DMBXR2'
SecId::FIGI.restore!('BBG000DMBXR')    # => #<SecId::FIGI>
SecId::FIGI.check_digit('BBG000DMBXR') # => 2

# instance level
figi = SecId::FIGI.new('BBG000DMBXR2')
figi.full_id               # => 'BBG000DMBXR2'
figi.prefix                # => 'BB'
figi.random_part           # => '000DMBXR'
figi.check_digit           # => 2
figi.valid?                # => true
figi.restore               # => 'BBG000DMBXR2'
figi.restore!              # => #<SecId::FIGI> (mutates instance)
figi.calculate_check_digit # => 2
```

### LEI

> [Legal Entity Identifier](https://en.wikipedia.org/wiki/Legal_Entity_Identifier) - a 20-character alphanumeric code that uniquely identifies legal entities participating in financial transactions.

```ruby
# class level
SecId::LEI.valid?('5493006MHB84DD0ZWV18')    # => true
SecId::LEI.restore('5493006MHB84DD0ZWV')     # => '5493006MHB84DD0ZWV18'
SecId::LEI.restore!('5493006MHB84DD0ZWV')    # => #<SecId::LEI>
SecId::LEI.check_digit('5493006MHB84DD0ZWV') # => 18

# instance level
lei = SecId::LEI.new('5493006MHB84DD0ZWV18')
lei.full_id               # => '5493006MHB84DD0ZWV18'
lei.lou_id                # => '5493'
lei.reserved              # => '00'
lei.entity_id             # => '6MHB84DD0ZWV'
lei.check_digit           # => 18
lei.valid?                # => true
lei.restore               # => '5493006MHB84DD0ZWV18'
lei.restore!              # => #<SecId::LEI> (mutates instance)
lei.calculate_check_digit # => 18
```

### IBAN

> [International Bank Account Number](https://en.wikipedia.org/wiki/International_Bank_Account_Number) - an internationally standardized system for identifying bank accounts across national borders (ISO 13616).

```ruby
# class level
SecId::IBAN.valid?('DE89370400440532013000')    # => true
SecId::IBAN.restore('DE370400440532013000')     # => 'DE89370400440532013000'
SecId::IBAN.restore!('DE370400440532013000')    # => #<SecId::IBAN>
SecId::IBAN.check_digit('DE370400440532013000') # => 89

# instance level
iban = SecId::IBAN.new('DE89370400440532013000')
iban.full_id               # => 'DE89370400440532013000'
iban.country_code          # => 'DE'
iban.bban                  # => '370400440532013000'
iban.bank_code             # => '37040044'
iban.account_number        # => '0532013000'
iban.check_digit           # => 89
iban.valid?                # => true
iban.restore               # => 'DE89370400440532013000'
iban.restore!              # => #<SecId::IBAN> (mutates instance)
iban.calculate_check_digit # => 89
iban.known_country?        # => true
```

Full BBAN structural validation is supported for EU/EEA countries. Other countries have length-only validation.

### CIK

> [Central Index Key](https://en.wikipedia.org/wiki/Central_Index_Key) - a 10-digit number used by the SEC to identify corporations and individuals who have filed disclosures.

```ruby
# class level
SecId::CIK.valid?('0001094517')    # => true
SecId::CIK.normalize('1094517')    # => '0001094517'

# instance level
cik = SecId::CIK.new('0001094517')
cik.full_id       # => '0001094517'
cik.padding       # => '000'
cik.identifier    # => '1094517'
cik.valid?        # => true
cik.normalized    # => '0001094517'
cik.normalize!    # => #<SecId::CIK> (mutates full_id, returns self)
```

### OCC

> [Options Clearing Corporation Symbol](https://en.wikipedia.org/wiki/Option_symbol#The_OCC_Option_Symbol) - a 16-to-21-character code used to identify equity options contracts.

```ruby
# class level
SecId::OCC.valid?('BRKB  100417C00090000')    # => true
SecId::OCC.normalize('BRKB100417C00090000')   # => 'BRKB  100417C00090000'
SecId::OCC.build(
  underlying: 'BRKB',
  date: Date.new(2010, 4, 17),
  type: 'C',
  strike: 90,
)                                                 # => #<SecId::OCC>

# instance level
occ = SecId::OCC.new('BRKB  100417C00090000')
occ.full_id       # => 'BRKB  100417C00090000'
occ.underlying    # => 'BRKB'
occ.date_str      # => '100417'
occ.date_obj      # => #<Date: 2010-04-17>
occ.type          # => 'C'
occ.strike        # => 90.0
occ.valid?        # => true
occ.normalized    # => 'BRKB  100417C00090000'

occ = SecId::OCC.new('X 250620C00050000')
occ.full_id       # => 'X 250620C00050000'
occ.valid?        # => true
occ.normalize!    # => #<SecId::OCC> (mutates full_id, returns self)
occ.full_id       # => 'X     250620C00050000'
```

### WKN

> [Wertpapierkennnummer](https://en.wikipedia.org/wiki/Wertpapierkennnummer) - a 6-character alphanumeric code used to identify securities in Germany.

```ruby
# class level
SecId::WKN.valid?('514000')  # => true
SecId::WKN.valid?('CBK100')  # => true

# instance level
wkn = SecId::WKN.new('514000')
wkn.full_id       # => '514000'
wkn.identifier    # => '514000'
wkn.valid?        # => true
wkn.to_s          # => '514000'
wkn.to_isin       # => #<SecId::ISIN> (DE ISIN)
```

WKN excludes letters I and O to avoid confusion with digits 1 and 0.

### Valoren

> [Valoren](https://en.wikipedia.org/wiki/Valoren_number) - a numeric identifier for securities in Switzerland, Liechtenstein, and Belgium.

```ruby
# class level
SecId::Valoren.valid?('3886335')        # => true
SecId::Valoren.valid?('24476758')       # => true
SecId::Valoren.valid?('35514757')       # => true
SecId::Valoren.valid?('97429325')       # => true
SecId::Valoren.normalize('3886335')     # => '003886335'

# instance level
valoren = SecId::Valoren.new('3886335')
valoren.full_id       # => '3886335'
valoren.padding       # => ''
valoren.identifier    # => '3886335'
valoren.valid?        # => true
valoren.normalized    # => '003886335'
valoren.normalize!    # => #<SecId::Valoren> (mutates full_id, returns self)
valoren.to_isin       # => #<SecId::ISIN> (CH ISIN by default)
valoren.to_isin('LI') # => #<SecId::ISIN> (LI ISIN)
```

### CFI

> [Classification of Financial Instruments](https://en.wikipedia.org/wiki/ISO_10962) - a 6-character alphabetic code that classifies financial instruments per ISO 10962.

```ruby
# class level
SecId::CFI.valid?('ESXXXX')        # => true
SecId::CFI.valid?('ESVUFR')        # => true
# instance level
cfi = SecId::CFI.new('ESVUFR')
cfi.full_id        # => 'ESVUFR'
cfi.identifier     # => 'ESVUFR'
cfi.category_code  # => 'E'
cfi.group_code     # => 'S'
cfi.category       # => :equity
cfi.group          # => :common_shares
cfi.valid?         # => true

# Equity-specific predicates
cfi.equity?        # => true
cfi.voting?        # => true
cfi.restrictions?  # => false
cfi.fully_paid?    # => true
cfi.registered?    # => true
```

CFI validates the category code (position 1) against 14 valid values and the group code (position 2) against valid values for that category. Attribute positions 3-6 accept any letter A-Z, with X meaning "not applicable".

### FISN

> [Financial Instrument Short Name](https://en.wikipedia.org/wiki/ISO_18774) - a human-readable short name for financial instruments per ISO 18774.

```ruby
# class level
SecId::FISN.valid?('APPLE INC/SH')        # => true
SecId::FISN.valid?('apple inc/sh')        # => true (normalized to uppercase)
# instance level
fisn = SecId::FISN.new('APPLE INC/SH')
fisn.full_id       # => 'APPLE INC/SH'
fisn.identifier    # => 'APPLE INC/SH'
fisn.issuer        # => 'APPLE INC'
fisn.description   # => 'SH'
fisn.valid?        # => true
fisn.to_s          # => 'APPLE INC/SH'
```

FISN format: `Issuer Name/Abbreviated Instrument Description` with issuer (1-15 chars) and description (1-19 chars) separated by a forward slash. Character set: uppercase A-Z, digits 0-9, and space.

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `bundle exec rake` to run the tests. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Make your changes and run tests (`bundle exec rake`)
4. Commit using [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format (`git commit -m 'feat: add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

## Versioning

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)

## License

The gem is available as open source under the terms of
the [MIT License](LICENSE.txt).
