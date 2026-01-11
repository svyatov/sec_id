# SecId [![Gem Version](https://img.shields.io/gem/v/sec_id)](https://rubygems.org/gems/sec_id) [![Codecov](https://img.shields.io/codecov/c/github/svyatov/sec_id)](https://app.codecov.io/gh/svyatov/sec_id) [![CI](https://github.com/svyatov/sec_id/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/svyatov/sec_id/actions?query=workflow%3ACI) [![License](https://img.shields.io/github/license/svyatov/sec_id)](LICENSE.txt)

> Validate securities identification numbers with ease!

## Table of Contents

- [Supported Ruby Versions](#supported-ruby-versions)
- [Installation](#installation)
- [Supported Standards and Usage](#supported-standards-and-usage)
  - [ISIN](#isin) - International Securities Identification Number
  - [CUSIP](#cusip) - Committee on Uniform Securities Identification Procedures
  - [SEDOL](#sedol) - Stock Exchange Daily Official List
  - [FIGI](#figi) - Financial Instrument Global Identifier
  - [CIK](#cik) - Central Index Key
  - [OCC](#occ) - Options Clearing Corporation Symbol
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

**Work in progress:** IBAN (International Bank Account Number)

## Supported Ruby Versions

Ruby 3.1+ is required.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sec_id', '~> 4.2'
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

All identifier classes provide `valid?` and `valid_format?` methods at both class and instance levels.

**Check-digit based identifiers** (ISIN, CUSIP, SEDOL, FIGI) also provide:
- `restore!` - restores check-digit and returns the full number
- `check_digit` / `calculate_check_digit` - calculates and returns the check-digit

**Normalization based identifiers** (CIK, OCC) provide instead:
- `normalize!` - pads/formats the identifier to its standard form

### ISIN

> [International Securities Identification Number](https://en.wikipedia.org/wiki/International_Securities_Identification_Number) - a 12-character alphanumeric code that uniquely identifies a security.

```ruby
# class level
SecId::ISIN.valid?('US5949181045')       # => true
SecId::ISIN.valid_format?('US594918104') # => true
SecId::ISIN.restore!('US594918104')      # => 'US5949181045'
SecId::ISIN.check_digit('US594918104')   # => 5

# instance level
isin = SecId::ISIN.new('US5949181045')
isin.full_number           # => 'US5949181045'
isin.country_code          # => 'US'
isin.nsin                  # => '594918104'
isin.check_digit           # => 5
isin.valid?                # => true
isin.valid_format?         # => true
isin.restore!              # => 'US5949181045'
isin.calculate_check_digit # => 5
isin.to_cusip              # => #<SecId::CUSIP>
```

### CUSIP

> [Committee on Uniform Securities Identification Procedures](https://en.wikipedia.org/wiki/CUSIP) - a 9-character alphanumeric code that identifies North American securities.

```ruby
# class level
SecId::CUSIP.valid?('594918104')       # => true
SecId::CUSIP.valid_format?('59491810') # => true
SecId::CUSIP.restore!('59491810')      # => '594918104'
SecId::CUSIP.check_digit('59491810')   # => 4

# instance level
cusip = SecId::CUSIP.new('594918104')
cusip.full_number           # => '594918104'
cusip.cusip6                # => '594918'
cusip.issue                 # => '10'
cusip.check_digit           # => 4
cusip.valid?                # => true
cusip.valid_format?         # => true
cusip.restore!              # => '594918104'
cusip.calculate_check_digit # => 4
cusip.to_isin('US')         # => #<SecId::ISIN>
cusip.cins?                 # => false
```

### SEDOL

> [Stock Exchange Daily Official List](https://en.wikipedia.org/wiki/SEDOL) - a 7-character alphanumeric code used in the United Kingdom and Ireland.

```ruby
# class level
SecId::SEDOL.valid?('B0Z52W5')       # => true
SecId::SEDOL.valid_format?('B0Z52W') # => true
SecId::SEDOL.restore!('B0Z52W')      # => 'B0Z52W5'
SecId::SEDOL.check_digit('B0Z52W')   # => 5

# instance level
sedol = SecId::SEDOL.new('B0Z52W5')
sedol.full_number           # => 'B0Z52W5'
sedol.check_digit           # => 5
sedol.valid?                # => true
sedol.valid_format?         # => true
sedol.restore!              # => 'B0Z52W5'
sedol.calculate_check_digit # => 5
```

### FIGI

> [Financial Instrument Global Identifier](https://en.wikipedia.org/wiki/Financial_Instrument_Global_Identifier) - a 12-character alphanumeric code that provides unique identification of financial instruments.

```ruby
# class level
SecId::FIGI.valid?('BBG000DMBXR2')        # => true
SecId::FIGI.valid_format?('BBG000DMBXR2') # => true
SecId::FIGI.restore!('BBG000DMBXR')       # => 'BBG000DMBXR2'
SecId::FIGI.check_digit('BBG000DMBXR')    # => 2

# instance level
figi = SecId::FIGI.new('BBG000DMBXR2')
figi.full_number           # => 'BBG000DMBXR2'
figi.prefix                # => 'BB'
figi.random_part           # => '000DMBXR'
figi.check_digit           # => 2
figi.valid?                # => true
figi.valid_format?         # => true
figi.restore!              # => 'BBG000DMBXR2'
figi.calculate_check_digit # => 2
```

### CIK

> [Central Index Key](https://en.wikipedia.org/wiki/Central_Index_Key) - a 10-digit number used by the SEC to identify corporations and individuals who have filed disclosures.

```ruby
# class level
SecId::CIK.valid?('0001094517')        # => true
SecId::CIK.valid_format?('0001094517') # => true
SecId::CIK.normalize!('1094517')       # => '0001094517'

# instance level
cik = SecId::CIK.new('0001094517')
cik.full_number   # => '0001094517'
cik.padding       # => '000'
cik.identifier    # => '1094517'
cik.valid?        # => true
cik.valid_format? # => true
cik.normalize!    # => '0001094517'
cik.to_s          # => '0001094517'
```

### OCC

> [Options Clearing Corporation Symbol](https://en.wikipedia.org/wiki/Option_symbol#The_OCC_Option_Symbol) - a 21-character code used to identify equity options contracts.

```ruby
# class level
SecId::OCC.valid?('BRKB  100417C00090000')        # => true
SecId::OCC.valid_format?('BRKB  100417C00090000') # => true
SecId::OCC.normalize!('BRKB100417C00090000')      # => 'BRKB  100417C00090000'
SecId::OCC.build(
  underlying: 'BRKB',
  date: Date.new(2010, 4, 17),
  type: 'C',
  strike: 90,
)                                                 # => #<SecId::OCC>

# instance level
occ = SecId::OCC.new('BRKB  100417C00090000')
occ.full_symbol   # => 'BRKB  100417C00090000'
occ.underlying    # => 'BRKB'
occ.date_str      # => '100417'
occ.date_obj      # => #<Date: 2010-04-17>
occ.type          # => 'C'
occ.strike        # => 90.0
occ.valid?        # => true
occ.valid_format? # => true
occ.normalize!    # => 'BRKB  100417C00090000'

occ = SecId::OCC.new('BRKB 2010-04-17C00090000')
occ.valid_format? # => false
occ.normalize!    # raises SecId::InvalidFormatError

occ = SecId::OCC.new('X 250620C00050000')
occ.full_symbol   # => 'X 250620C00050000'
occ.valid?        # => true
occ.normalize!    # => 'X     250620C00050000'
occ.full_symbol   # => 'X     250620C00050000'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake spec` to run the tests. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on
GitHub at https://github.com/svyatov/sec_id.

## License

The gem is available as open source under the terms of
the [MIT License](LICENSE.txt).
