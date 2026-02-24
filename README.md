# SecID [![Gem Version](https://img.shields.io/gem/v/sec_id)](https://rubygems.org/gems/sec_id) [![Codecov](https://img.shields.io/codecov/c/github/svyatov/sec_id)](https://app.codecov.io/gh/svyatov/sec_id) [![CI](https://github.com/svyatov/sec_id/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/svyatov/sec_id/actions?query=workflow%3ACI)

> A Ruby toolkit for securities identifiers — validate, parse, normalize, detect, and convert.

## Table of Contents

- [Supported Ruby Versions](#supported-ruby-versions)
- [Installation](#installation)
- [Supported Standards and Usage](#supported-standards-and-usage)
  - [Metadata Registry](#metadata-registry) - enumerate, filter, look up, and detect identifier types
  - [Text Scanning](#text-scanning) - find identifiers in freeform text
  - [Debugging Detection](#debugging-detection) - understand why strings match or don't
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
- [Lookup Service Integration](#lookup-service-integration)
- [Development](#development)
- [Contributing](#contributing)
- [Changelog](#changelog)
- [Versioning](#versioning)
- [License](#license)

## Supported Ruby Versions

Ruby 3.2+ is required.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sec_id', '~> 5.1'
```

And then execute:

```bash
bundle install
```

Or install it yourself:

```bash
gem install sec_id
```

**Upgrading from v4?** See [MIGRATION.md](MIGRATION.md) for a step-by-step guide.

## Supported Standards and Usage

All identifier classes provide `valid?`, `errors`, `validate`, `validate!` methods at both class and instance levels.

**All identifiers** support normalization and display formatting:
- `.normalize(id)` - strips separators, upcases, validates, and returns the canonical string
- `#normalized` / `#normalize` - returns the canonical string for a valid instance
- `#normalize!` - mutates `full_id` to canonical form, returns `self`
- `#to_pretty_s` / `.to_pretty_s(id)` - returns a human-readable formatted string, or `nil` for invalid input

**All identifiers** support hash serialization:
- `#to_h` - returns a hash with `:type`, `:full_id`, `:normalized`, `:valid`, and `:components` keys
- `#as_json` - same as `#to_h`, for JSON serialization compatibility (Rails, `JSON.generate`, etc.)

```ruby
SecID::ISIN.new('US5949181045').to_h
# => { type: :isin, full_id: 'US5949181045', normalized: 'US5949181045',
#      valid: true, components: { country_code: 'US', nsin: '594918104', check_digit: 5 } }

SecID::ISIN.new('INVALID').to_h
# => { type: :isin, full_id: 'INVALID', normalized: nil,
#      valid: false, components: { country_code: nil, nsin: nil, check_digit: nil } }
```

**All identifiers** support value equality — two instances of the same type with the same normalized form are equal:

```ruby
a = SecID::ISIN.new('US5949181045')
b = SecID::ISIN.new('us 5949 1810 45')

a == b  # => true
a.eql?(b) # => true

# Works as Hash keys and in Sets
{ a => 'MSFT' }[b]          # => 'MSFT'
Set.new([a, b]).size         # => 1
```

**Check-digit based identifiers** (ISIN, CUSIP, CEI, SEDOL, FIGI, LEI, IBAN) also provide:
- `restore` / `.restore` - returns the full identifier string with correct check-digit (no mutation)
- `restore!` / `.restore!` - restores check-digit in place and returns `self` / instance
- `check_digit` / `calculate_check_digit` - calculates and returns the check-digit

### Metadata Registry

All identifier classes are registered automatically and can be enumerated, filtered, and looked up by symbol key:

```ruby
# Look up by symbol key
SecID[:isin]                              # => SecID::ISIN
SecID[:cusip]                             # => SecID::CUSIP

# Enumerate all identifier classes
SecID.identifiers                         # => [SecID::ISIN, SecID::CUSIP, ...]
SecID.identifiers.map(&:short_name)       # => ["ISIN", "CUSIP", "SEDOL", ...]

# Query metadata
SecID::ISIN.short_name                    # => "ISIN"
SecID::ISIN.full_name                     # => "International Securities Identification Number"
SecID::ISIN.id_length                     # => 12
SecID::ISIN.example                       # => "US5949181045"
SecID::ISIN.has_check_digit?              # => true

# Filter with standard Ruby
SecID.identifiers.select(&:has_check_digit?).map(&:short_name)
# => ["ISIN", "CUSIP", "SEDOL", "FIGI", "LEI", "IBAN", "CEI"]

# Detect identifier type from an unknown string
# Results are sorted by specificity: check-digit types first, then by length precision
SecID.detect('US5949181045')  # => [:isin]
SecID.detect('037833100')     # => [:cusip, :valoren, :cik]
SecID.detect('APPLE INC/SH')  # => [:fisn]
SecID.detect('INVALID')       # => []

# Quick boolean validation
SecID.valid?('US5949181045')                      # => true (any type)
SecID.valid?('INVALID')                           # => false
SecID.valid?('US5949181045', types: [:isin])      # => true
SecID.valid?('594918104', types: %i[cusip sedol]) # => true
SecID.valid?('US5949181045', types: [:cusip])     # => false

# Parse into a typed instance (returns the most specific match)
SecID.parse('US5949181045')                       # => #<SecID::ISIN>
SecID.parse('594918104')                          # => #<SecID::CUSIP>
SecID.parse('unknown')                            # => nil
SecID.parse('594918104', types: [:cusip])         # => #<SecID::CUSIP>

# Bang version raises on failure
SecID.parse!('US5949181045')                      # => #<SecID::ISIN>
SecID.parse!('unknown')                           # raises SecID::InvalidFormatError

# Handle ambiguous matches
SecID.parse('514000', on_ambiguous: :first)        # => #<SecID::WKN> (default)
SecID.parse('514000', on_ambiguous: :raise)        # raises SecID::AmbiguousMatchError
SecID.parse('514000', on_ambiguous: :all)          # => [#<SecID::WKN>, #<SecID::Valoren>, #<SecID::CIK>]
SecID.parse('US5949181045', on_ambiguous: :raise)  # => #<SecID::ISIN> (unambiguous, no error)
```

### Text Scanning

Find identifiers embedded in freeform text:

```ruby
# Extract all identifiers from text
matches = SecID.extract('Portfolio: US5949181045, 594918104, B0YBKJ7')
matches.map(&:type)   # => [:isin, :cusip, :sedol]
matches.first.raw     # => "US5949181045"
matches.first.range   # => 11...23
matches.first.identifier.country_code  # => "US"

# Lazy scanning with Enumerator
SecID.scan('Buy US5949181045 now').each { |m| puts m.type }

# Filter by types
SecID.extract('514000', types: [:valoren])  # => only Valoren matches

# Handles hyphenated identifiers
match = SecID.extract('ID: US-5949-1810-45').first
match.raw                    # => "US-5949-1810-45"
match.identifier.normalized  # => "US5949181045"
```

> **Known limitations:** Format-only types (CIK, Valoren, WKN, CFI) can false-positive on
> common numbers and short words in prose — use the `types:` filter to restrict scanning when
> this is a concern. Identifiers prefixed with special characters (e.g. `#US5949181045`) may be
> consumed as a single token by CUSIP's `*@#` character class and fail validation, preventing
> the embedded identifier from being found.

### Debugging Detection

Understand why a string matches or doesn't match specific identifier types:

```ruby
result = SecID.explain('US5949181040')
isin = result[:candidates].find { |c| c[:type] == :isin }
isin[:valid]                      # => false
isin[:errors].first[:error]       # => :invalid_check_digit

# Filter to specific types
SecID.explain('US5949181045', types: %i[isin cusip])
```

### Structured Validation

All identifier classes provide a Rails-like `#errors` API for detailed error reporting:

```ruby
isin = SecID::ISIN.new('US5949181040')
isin.errors.none?     # => false
isin.errors.messages  # => ["Check digit '0' is invalid, expected '5'"]
isin.errors.details   # => [{ error: :invalid_check_digit, message: "Check digit '0' is invalid, expected '5'" }]
isin.errors.any?      # => true
isin.errors.empty?    # => false
isin.errors.size      # => 1
isin.errors.to_a      # => same as messages

# Class-level convenience method (returns the instance with errors cached)
SecID::ISIN.validate('US5949181040')         # => #<SecID::ISIN>
SecID::ISIN.validate('US5949181040').errors   # => #<SecID::Errors>
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
SecID::ISIN.new('US5949181045').validate!  # => #<SecID::ISIN>

# Raises with a descriptive message when invalid
SecID::ISIN.new('INVALID').validate!
# => SecID::InvalidFormatError: Expected 12 characters, got 7

SecID::ISIN.new('US5949181040').validate!
# => SecID::InvalidCheckDigitError: Check digit '0' is invalid, expected '5'

SecID::FIGI.new('BSG000BLNNH6').validate!
# => SecID::InvalidStructureError: Prefix 'BS' is restricted

# Class-level convenience method (returns the instance)
isin = SecID::ISIN.validate!('US5949181045')  # => #<SecID::ISIN>
```

### ISIN

> [International Securities Identification Number](https://en.wikipedia.org/wiki/International_Securities_Identification_Number) - a 12-character alphanumeric code that uniquely identifies a security.

```ruby
# class level
SecID::ISIN.valid?('US5949181045')      # => true
SecID::ISIN.restore('US594918104')      # => 'US5949181045'
SecID::ISIN.restore!('US594918104')     # => #<SecID::ISIN>
SecID::ISIN.check_digit('US594918104')  # => 5

# instance level
isin = SecID::ISIN.new('US5949181045')
isin.full_id               # => 'US5949181045'
isin.country_code          # => 'US'
isin.nsin                  # => '594918104'
isin.check_digit           # => 5
isin.valid?                # => true
isin.restore               # => 'US5949181045'
isin.restore!              # => #<SecID::ISIN> (mutates instance)
isin.calculate_check_digit # => 5
isin.to_pretty_s           # => 'US 594918104 5'
isin.to_cusip              # => #<SecID::CUSIP>
isin.nsin_type             # => :cusip
isin.to_nsin               # => #<SecID::CUSIP>

# NSIN extraction for different countries
SecID::ISIN.new('GB00B02H2F76').nsin_type  # => :sedol
SecID::ISIN.new('GB00B02H2F76').to_nsin    # => #<SecID::SEDOL>
SecID::ISIN.new('DE0007164600').nsin_type  # => :wkn
SecID::ISIN.new('DE0007164600').to_nsin    # => #<SecID::WKN>
SecID::ISIN.new('CH0012221716').nsin_type  # => :valoren
SecID::ISIN.new('CH0012221716').to_nsin    # => #<SecID::Valoren>
SecID::ISIN.new('FR0000120271').nsin_type  # => :generic
SecID::ISIN.new('FR0000120271').to_nsin    # => '000012027' (raw NSIN string)

# Type-specific conversion methods with validation
SecID::ISIN.new('GB00B02H2F76').sedol?     # => true
SecID::ISIN.new('GB00B02H2F76').to_sedol   # => #<SecID::SEDOL>
SecID::ISIN.new('DE0007164600').wkn?       # => true
SecID::ISIN.new('DE0007164600').to_wkn     # => #<SecID::WKN>
SecID::ISIN.new('CH0012221716').valoren?   # => true
SecID::ISIN.new('CH0012221716').to_valoren # => #<SecID::Valoren>
```

### CUSIP

> [Committee on Uniform Securities Identification Procedures](https://en.wikipedia.org/wiki/CUSIP) - a 9-character alphanumeric code that identifies North American securities.

```ruby
# class level
SecID::CUSIP.valid?('594918104')      # => true
SecID::CUSIP.restore('59491810')      # => '594918104'
SecID::CUSIP.restore!('59491810')     # => #<SecID::CUSIP>
SecID::CUSIP.check_digit('59491810')  # => 4

# instance level
cusip = SecID::CUSIP.new('594918104')
cusip.full_id               # => '594918104'
cusip.cusip6                # => '594918'
cusip.issue                 # => '10'
cusip.check_digit           # => 4
cusip.valid?                # => true
cusip.restore               # => '594918104'
cusip.restore!              # => #<SecID::CUSIP> (mutates instance)
cusip.calculate_check_digit # => 4
cusip.to_pretty_s           # => '594918 10 4'
cusip.to_isin('US')         # => #<SecID::ISIN>
cusip.cins?                 # => false
```

### CEI

> [CUSIP Entity Identifier](https://www.cusip.com/identifiers.html) - a 10-character alphanumeric code that identifies legal entities in the syndicated loan market.

```ruby
# class level
SecID::CEI.valid?('A0BCDEFGH1')      # => true
SecID::CEI.restore('A0BCDEFGH')      # => 'A0BCDEFGH1'
SecID::CEI.restore!('A0BCDEFGH')     # => #<SecID::CEI>
SecID::CEI.check_digit('A0BCDEFGH')  # => 1

# instance level
cei = SecID::CEI.new('A0BCDEFGH1')
cei.full_id               # => 'A0BCDEFGH1'
cei.prefix                # => 'A'
cei.numeric               # => '0'
cei.entity_id             # => 'BCDEFGH'
cei.check_digit           # => 1
cei.valid?                # => true
cei.restore               # => 'A0BCDEFGH1'
cei.restore!              # => #<SecID::CEI> (mutates instance)
cei.calculate_check_digit # => 1
```

### SEDOL

> [Stock Exchange Daily Official List](https://en.wikipedia.org/wiki/SEDOL) - a 7-character alphanumeric code used in the United Kingdom, Ireland, Crown Dependencies (Jersey, Guernsey, Isle of Man), and select British Overseas Territories.

```ruby
# class level
SecID::SEDOL.valid?('B0Z52W5')      # => true
SecID::SEDOL.restore('B0Z52W')      # => 'B0Z52W5'
SecID::SEDOL.restore!('B0Z52W')     # => #<SecID::SEDOL>
SecID::SEDOL.check_digit('B0Z52W')  # => 5

# instance level
sedol = SecID::SEDOL.new('B0Z52W5')
sedol.full_id               # => 'B0Z52W5'
sedol.check_digit           # => 5
sedol.valid?                # => true
sedol.restore               # => 'B0Z52W5'
sedol.restore!              # => #<SecID::SEDOL> (mutates instance)
sedol.calculate_check_digit # => 5
sedol.to_isin               # => #<SecID::ISIN> (GB ISIN by default)
sedol.to_isin('IE')         # => #<SecID::ISIN> (IE ISIN)
```

### FIGI

> [Financial Instrument Global Identifier](https://en.wikipedia.org/wiki/Financial_Instrument_Global_Identifier) - a 12-character alphanumeric code that provides unique identification of financial instruments.

```ruby
# class level
SecID::FIGI.valid?('BBG000DMBXR2')     # => true
SecID::FIGI.restore('BBG000DMBXR')     # => 'BBG000DMBXR2'
SecID::FIGI.restore!('BBG000DMBXR')    # => #<SecID::FIGI>
SecID::FIGI.check_digit('BBG000DMBXR') # => 2

# instance level
figi = SecID::FIGI.new('BBG000DMBXR2')
figi.full_id               # => 'BBG000DMBXR2'
figi.prefix                # => 'BB'
figi.random_part           # => '000DMBXR'
figi.check_digit           # => 2
figi.valid?                # => true
figi.restore               # => 'BBG000DMBXR2'
figi.restore!              # => #<SecID::FIGI> (mutates instance)
figi.calculate_check_digit # => 2
figi.to_pretty_s           # => 'BBG 000DMBXR 2'
```

### LEI

> [Legal Entity Identifier](https://en.wikipedia.org/wiki/Legal_Entity_Identifier) - a 20-character alphanumeric code that uniquely identifies legal entities participating in financial transactions.

```ruby
# class level
SecID::LEI.valid?('5493006MHB84DD0ZWV18')    # => true
SecID::LEI.restore('5493006MHB84DD0ZWV')     # => '5493006MHB84DD0ZWV18'
SecID::LEI.restore!('5493006MHB84DD0ZWV')    # => #<SecID::LEI>
SecID::LEI.check_digit('5493006MHB84DD0ZWV') # => 18

# instance level
lei = SecID::LEI.new('5493006MHB84DD0ZWV18')
lei.full_id               # => '5493006MHB84DD0ZWV18'
lei.lou_id                # => '5493'
lei.reserved              # => '00'
lei.entity_id             # => '6MHB84DD0ZWV'
lei.check_digit           # => 18
lei.valid?                # => true
lei.restore               # => '5493006MHB84DD0ZWV18'
lei.restore!              # => #<SecID::LEI> (mutates instance)
lei.calculate_check_digit # => 18
lei.to_pretty_s           # => '5493 006M HB84 DD0Z WV18'
```

### IBAN

> [International Bank Account Number](https://en.wikipedia.org/wiki/International_Bank_Account_Number) - an internationally standardized system for identifying bank accounts across national borders (ISO 13616).

```ruby
# class level
SecID::IBAN.valid?('DE89370400440532013000')    # => true
SecID::IBAN.restore('DE370400440532013000')     # => 'DE89370400440532013000'
SecID::IBAN.restore!('DE370400440532013000')    # => #<SecID::IBAN>
SecID::IBAN.check_digit('DE370400440532013000') # => 89

# instance level
iban = SecID::IBAN.new('DE89370400440532013000')
iban.full_id               # => 'DE89370400440532013000'
iban.country_code          # => 'DE'
iban.bban                  # => '370400440532013000'
iban.bank_code             # => '37040044'
iban.account_number        # => '0532013000'
iban.check_digit           # => 89
iban.valid?                # => true
iban.restore               # => 'DE89370400440532013000'
iban.restore!              # => #<SecID::IBAN> (mutates instance)
iban.calculate_check_digit # => 89
iban.known_country?        # => true
iban.to_pretty_s           # => 'DE89 3704 0044 0532 0130 00'
```

Full BBAN structural validation is supported for EU/EEA countries. Other countries have length-only validation.

```ruby
# List all supported countries
SecID::IBAN.supported_countries  # => ["AD", "AE", "AT", "BE", "BG", "CH", ...]
```

### CIK

> [Central Index Key](https://en.wikipedia.org/wiki/Central_Index_Key) - a 10-digit number used by the SEC to identify corporations and individuals who have filed disclosures.

```ruby
# class level
SecID::CIK.valid?('0001094517')    # => true
SecID::CIK.normalize('1094517')    # => '0001094517'

# instance level
cik = SecID::CIK.new('0001094517')
cik.full_id       # => '0001094517'
cik.padding       # => '000'
cik.identifier    # => '1094517'
cik.valid?        # => true
cik.normalized    # => '0001094517'
cik.normalize!    # => #<SecID::CIK> (mutates full_id, returns self)
```

### OCC

> [Options Clearing Corporation Symbol](https://en.wikipedia.org/wiki/Option_symbol#The_OCC_Option_Symbol) - a 16-to-21-character code used to identify equity options contracts.

```ruby
# class level
SecID::OCC.valid?('BRKB  100417C00090000')    # => true
SecID::OCC.normalize('BRKB100417C00090000')   # => 'BRKB  100417C00090000'
SecID::OCC.build(
  underlying: 'BRKB',
  date: Date.new(2010, 4, 17),
  type: 'C',
  strike: 90,
)                                                 # => #<SecID::OCC>

# instance level
occ = SecID::OCC.new('BRKB  100417C00090000')
occ.full_id       # => 'BRKB  100417C00090000'
occ.underlying    # => 'BRKB'
occ.date_str      # => '100417'
occ.date_obj      # => #<Date: 2010-04-17>
occ.type          # => 'C'
occ.strike        # => 90.0
occ.valid?        # => true
occ.normalized    # => 'BRKB  100417C00090000'

occ = SecID::OCC.new('X 250620C00050000')
occ.full_id       # => 'X 250620C00050000'
occ.valid?        # => true
occ.normalize!    # => #<SecID::OCC> (mutates full_id, returns self)
occ.full_id       # => 'X     250620C00050000'
occ.to_pretty_s   # => 'X 250620 C 00050000'
```

### WKN

> [Wertpapierkennnummer](https://en.wikipedia.org/wiki/Wertpapierkennnummer) - a 6-character alphanumeric code used to identify securities in Germany.

```ruby
# class level
SecID::WKN.valid?('514000')  # => true
SecID::WKN.valid?('CBK100')  # => true

# instance level
wkn = SecID::WKN.new('514000')
wkn.full_id       # => '514000'
wkn.identifier    # => '514000'
wkn.valid?        # => true
wkn.to_s          # => '514000'
wkn.to_isin       # => #<SecID::ISIN> (DE ISIN)
```

WKN excludes letters I and O to avoid confusion with digits 1 and 0.

### Valoren

> [Valoren](https://en.wikipedia.org/wiki/Valoren_number) - a numeric identifier for securities in Switzerland, Liechtenstein, and Belgium.

```ruby
# class level
SecID::Valoren.valid?('3886335')        # => true
SecID::Valoren.valid?('24476758')       # => true
SecID::Valoren.valid?('35514757')       # => true
SecID::Valoren.valid?('97429325')       # => true
SecID::Valoren.normalize('3886335')     # => '003886335'

# instance level
valoren = SecID::Valoren.new('3886335')
valoren.full_id       # => '3886335'
valoren.padding       # => ''
valoren.identifier    # => '3886335'
valoren.valid?        # => true
valoren.normalized    # => '003886335'
valoren.normalize!    # => #<SecID::Valoren> (mutates full_id, returns self)
valoren.to_pretty_s   # => '3 886 335'
valoren.to_isin       # => #<SecID::ISIN> (CH ISIN by default)
valoren.to_isin('LI') # => #<SecID::ISIN> (LI ISIN)
```

### CFI

> [Classification of Financial Instruments](https://en.wikipedia.org/wiki/ISO_10962) - a 6-character alphabetic code that classifies financial instruments per ISO 10962.

```ruby
# class level
SecID::CFI.valid?('ESXXXX')        # => true
SecID::CFI.valid?('ESVUFR')        # => true
# instance level
cfi = SecID::CFI.new('ESVUFR')
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

```ruby
# Introspect valid codes
SecID::CFI.categories            # => { "E" => :equity, "C" => :collective_investment_vehicles, ... }
SecID::CFI.groups_for('E')       # => { "S" => :common_shares, "P" => :preferred_shares, ... }
```

### FISN

> [Financial Instrument Short Name](https://en.wikipedia.org/wiki/ISO_18774) - a human-readable short name for financial instruments per ISO 18774.

```ruby
# class level
SecID::FISN.valid?('APPLE INC/SH')        # => true
SecID::FISN.valid?('apple inc/sh')        # => true (normalized to uppercase)
# instance level
fisn = SecID::FISN.new('APPLE INC/SH')
fisn.full_id       # => 'APPLE INC/SH'
fisn.identifier    # => 'APPLE INC/SH'
fisn.issuer        # => 'APPLE INC'
fisn.description   # => 'SH'
fisn.valid?        # => true
fisn.to_s          # => 'APPLE INC/SH'
```

FISN format: `Issuer Name/Abbreviated Instrument Description` with issuer (1-15 chars) and description (1-19 chars) separated by a forward slash. Character set: uppercase A-Z, digits 0-9, and space.

## Lookup Service Integration

SecID validates identifiers but does not include HTTP clients. The [`docs/guides/`](docs/guides/) directory provides integration patterns for external lookup services using only stdlib (`net/http`, `json`):

| Guide | Service | Identifier |
|-------|---------|------------|
| [OpenFIGI](docs/guides/openfigi.md) | [OpenFIGI API](https://www.openfigi.com/api) | FIGI |
| [SEC EDGAR](docs/guides/sec-edgar.md) | [SEC EDGAR](https://www.sec.gov/edgar/sec-api-documentation) | CIK |
| [GLEIF](docs/guides/gleif.md) | [GLEIF API](https://www.gleif.org/en/lei-data/gleif-api) | LEI |
| [Eurex](docs/guides/eurex.md) | [Eurex Reference Data](https://www.eurex.com/ex-en/data/free-reference-data-api) | ISIN |

Each guide includes a complete adapter class and a [runnable example](examples/).

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `bundle exec rake` to run the tests. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/svyatov/sec_id). See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style, and PR guidelines.

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

## Versioning

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)

## License

The gem is available as open source under the terms of
the [MIT License](LICENSE.txt).
