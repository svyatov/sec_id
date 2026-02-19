# OpenFIGI API Integration

Look up financial instruments by FIGI using the [OpenFIGI API](https://www.openfigi.com/api).

## Service Overview

OpenFIGI provides free mapping between Financial Instrument Global Identifiers (FIGIs) and other market identifiers. The API maps FIGIs to instrument metadata including ticker, exchange, security type, and market sector.

- **Official docs:** https://www.openfigi.com/api/documentation
- **OpenAPI spec:** https://www.openfigi.com/api/openapi-spec

## Authentication

An API key is optional but recommended for higher rate limits. Register for a free key at https://www.openfigi.com/user/signup.

Pass the key via the `X-OPENFIGI-APIKEY` header.

## Adapter

```ruby
require 'sec_id'
require 'net/http'
require 'json'

class OpenFigiAdapter
  BASE_URL = 'https://api.openfigi.com'
  MAPPING_ENDPOINT = '/v3/mapping'

  def initialize(api_key: nil)
    @api_key = api_key || ENV['OPENFIGI_API_KEY']
  end

  # Look up a single FIGI.
  #
  # @param figi_str [String] a validated FIGI string
  # @return [Hash] instrument data
  def lookup(figi_str)
    body = [{ idType: 'ID_BB_GLOBAL', idValue: figi_str }]
    response = post(MAPPING_ENDPOINT, body)
    result = JSON.parse(response.body)

    entry = result.first
    raise "FIGI not found: #{figi_str} (#{entry['error']})" if entry.key?('error')

    instruments = entry.fetch('data', [])
    {
      figi: figi_str,
      instruments: instruments.map { |inst|
        {
          name: inst['name'],
          ticker: inst['ticker'],
          exchange: inst['exchCode'],
          security_type: inst['securityType'],
          market_sector: inst['marketSector']
        }
      }
    }
  end

  # Look up multiple FIGIs in a single batch request (max 100 with API key, 10 without).
  #
  # @param figi_strings [Array<String>]
  # @return [Array<Hash>]
  def batch_lookup(figi_strings)
    body = figi_strings.map { |f| { idType: 'ID_BB_GLOBAL', idValue: f } }
    response = post(MAPPING_ENDPOINT, body)
    JSON.parse(response.body)
  end

  private

  def post(path, body)
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    request['X-OPENFIGI-APIKEY'] = @api_key if @api_key
    request.body = JSON.generate(body)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    case response
    when Net::HTTPSuccess then response
    when Net::HTTPTooManyRequests
      raise "Rate limited. #{@api_key ? 'Try reducing batch size.' : 'Set OPENFIGI_API_KEY for higher limits.'}"
    else
      raise "OpenFIGI API error (#{response.code}): #{response.body}"
    end
  end
end
```

## Usage with sec_id

Validate with SecID, then pass the identifier to the adapter:

```ruby
adapter = OpenFigiAdapter.new(api_key: ENV['OPENFIGI_API_KEY'])

# validate! raises SecID::Error on invalid input, returns the instance on success
figi = SecID::FIGI.validate!('BBG000BLNNH6')
figi.to_pretty_s  # => "BBG 000BLNNH 6"
figi.check_digit  # => 6

result = adapter.lookup(figi.to_s)
result[:instruments].each do |inst|
  puts "#{inst[:ticker]} on #{inst[:exchange]}: #{inst[:name]}"
end
```

You can also look up other identifier types through the mapping API by changing `idType`:

```ruby
# Look up by ISIN
body = [{ idType: 'ID_ISIN', idValue: 'US5949181045' }]

# Look up by CUSIP
body = [{ idType: 'ID_CUSIP', idValue: '594918104' }]

# Look up by ticker with exchange filter
body = [{ idType: 'TICKER', idValue: 'MSFT', exchCode: 'US' }]
```

## Rate Limiting

| | Without API Key | With API Key |
|---|---|---|
| Max requests | 25/minute | 25/6 seconds |
| Max jobs per request | 10 | 100 |

The API returns rate-limit headers on every response:

- `ratelimit-limit` -- total allowed requests in the window
- `ratelimit-remaining` -- remaining requests
- `ratelimit-reset` -- seconds until reset

For simple stdlib-only throttling, sleep between requests:

```ruby
# Without API key: ~2.4s between requests to stay under 25/min
sleep 2.5

# With API key: ~0.24s between requests to stay under 25/6s
sleep 0.25
```

## Caching

FIGI-to-instrument mappings are stable. Cache aggressively:

- **FIGI lookups:** cache indefinitely (FIGIs don't change instruments)
- **Ticker lookups:** cache for 24 hours (ticker assignments can change)
- **Batch results:** cache per-FIGI within the batch response

A simple in-memory cache:

```ruby
@cache = {}

def cached_lookup(figi_str)
  @cache[figi_str] ||= lookup(figi_str)
end
```

## Error Handling

| Scenario | Response |
|---|---|
| FIGI not found | HTTP 200 with `"warning"` key in result element |
| Too many results | HTTP 200 with `"error"` key in result element |
| Invalid request | HTTP 400 |
| Bad API key | HTTP 401 |
| Too many jobs | HTTP 413 |
| Rate limited | HTTP 429 |
| Server error | HTTP 500 (retry with backoff) |

Note that a 200 response can still contain per-job errors. Always check each result element for `"error"` or `"warning"` keys.

## Runnable Example

See [`examples/openfigi_lookup.rb`](../../examples/openfigi_lookup.rb) for a self-contained script.
