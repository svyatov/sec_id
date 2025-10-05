# SecId
[![Gem Version](https://badge.fury.io/rb/sec_id.svg)](https://badge.fury.io/rb/sec_id)
![Build Status](https://github.com/svyatov/sec_id/actions/workflows/main.yml/badge.svg?branch=main)
[![Maintainability](https://api.codeclimate.com/v1/badges/a4759963a5ddc4d55b24/maintainability)](https://codeclimate.com/github/svyatov/sec_id/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/a4759963a5ddc4d55b24/test_coverage)](https://codeclimate.com/github/svyatov/sec_id/test_coverage)

Validate securities identification numbers with ease!

Check-digit calculation is also available.

Currently supported standards:
[ISIN](https://en.wikipedia.org/wiki/International_Securities_Identification_Number),
[CUSIP](https://en.wikipedia.org/wiki/CUSIP),
[SEDOL](https://en.wikipedia.org/wiki/SEDOL),
[FIGI](https://en.wikipedia.org/wiki/Financial_Instrument_Global_Identifier),
[CIK](https://en.wikipedia.org/wiki/Central_Index_Key).

Work in progress:
[IBAN](https://en.wikipedia.org/wiki/International_Bank_Account_Number).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sec_id', '~> 4.1'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sec_id

## Usage

### Base API

Base API has 4 main methods which can be used both on class level and on instance level:

* `valid?` - never raises any errors, always returns `true` or `false`,
  numbers without the check-digit will return `false`

  ```ruby
  # class level
  SecId::ISIN.valid?('US5949181045') # => true
  SecId::ISIN.valid?('US594918104')  # => false

  # instance level
  isin = SecId::ISIN.new('US5949181045')
  isin.valid? # => true
  ```

* `valid_format?` - never raises any errors, always returns `true` or `false`,
  numbers without the check-digit but in valid format will return `true`

  ```ruby
  # class level
  SecId::ISIN.valid_format?('US5949181045') # => true
  SecId::ISIN.valid_format?('US594918104') # => true

  # instance level
  isin = SecId::ISIN.new('US594918104')
  isin.valid_format? # => true
  ```

* `restore!` - restores check-digit and returns the full number,
  raises an error if number's format is invalid and thus check-digit is impossible to calculate

  ```ruby
  # class level
  SecId::ISIN.restore!('US594918104') # => 'US5949181045'

  # instance level
  isin = SecId::ISIN.new('US5949181045')
  isin.restore! # => 'US5949181045'
  ```

* `check_digit` and `calculate_check_digit` - these are the same,
  but the former is used at class level for bravity,
  and the latter is used at instance level for clarity;
  it calculates and returns the check-digit if the number is valid
  and raises an error otherwise.

  ```ruby
  # class level
  SecId::ISIN.check_digit('US594918104') # => 5

  # instance level
  isin = SecId::ISIN.new('US594918104')
  isin.calculate_check_digit # => 5
  isin.check_digit # => nil
  ```

  :exclamation: Please note that `isin.check_digit` returns `nil` because `#check_digit`
  at instance level represents original check-digit of the number passed to `new`,
  which in this example is missing and thus it's `nil`.

### SecId::ISIN full example

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

### SecId::CUSIP full example

```ruby
# class level
SecId::CUSIP.valid?('594918104')       # => true
SecId::CUSIP.valid_format?('59491810') # => true
SecId::CUSIP.restore!('59491810')      # => '594918104'
SecId::CUSIP.check_digit('59491810')   # => 5

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
cusip.cins?                 # => true
```

### SecId::SEDOL full example

```ruby
# class level
SecId::SEDOL.valid?('B0Z52W5')       # => true
SecId::SEDOL.valid_format?('B0Z52W') # => true
SecId::SEDOL.restore!('B0Z52W')      # => 'B0Z52W5'
SecId::SEDOL.check_digit('B0Z52W')   # => 5

# instance level
cusip = SecId::SEDOL.new('B0Z52W5')
cusip.full_number           # => 'B0Z52W5'
cusip.check_digit           # => 5
cusip.valid?                # => true
cusip.valid_format?         # => true
cusip.restore!              # => 'B0Z52W5'
cusip.calculate_check_digit # => 5
```

### SecId::FIGI full example

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

### SecId::CIK full example

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
