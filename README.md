# SecId

Validate security identification numbers with ease!

Check-digit calculation is also available.

Currently supported standards:
[ISIN](https://en.wikipedia.org/wiki/International_Securities_Identification_Number),
[CUSIP](https://en.wikipedia.org/wiki/CUSIP),
[SEDOL](https://en.wikipedia.org/wiki/SEDOL),
[IBAN](https://en.wikipedia.org/wiki/International_Bank_Account_Number).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sec_id', '~> 1.0'
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
isin.isin                  # => 'US5949181045'
isin.country_code          # => 'US'
isin.nsin                  # => '594918104'
isin.check_digit           # => 5
isin.valid?                # => true
isin.valid_format?         # => true
isin.restore!              # => 'US5949181045'
isin.calculate_check_digit # => 5
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
