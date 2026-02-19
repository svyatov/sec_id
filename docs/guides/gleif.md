# GLEIF API Integration

Look up legal entities by LEI using the [GLEIF API](https://www.gleif.org/en/lei-data/gleif-api).

## Service Overview

The Global Legal Entity Identifier Foundation (GLEIF) provides free access to LEI data. The API returns entity registration details, legal names, addresses, and relationship data for any valid LEI.

- **Official docs:** https://www.gleif.org/en/lei-data/gleif-api
- **API reference:** https://api.gleif.org/api/v1

## Authentication

No authentication required. The API is free and open.

## Adapter

```ruby
require 'sec_id'
require 'net/http'
require 'json'

class GleifAdapter
  BASE_URL = 'https://api.gleif.org/api/v1'

  def initialize
    @last_request_at = nil
  end

  # Look up a legal entity by LEI.
  #
  # @param lei_str [String]
  # @return [Hash] entity data
  # @param lei_str [String] a validated LEI
  def lookup(lei_str)
    rate_limit!
    response = get("/lei-records?filter[lei]=#{lei}")
    data = JSON.parse(response.body)

    records = data.fetch('data', [])
    raise "LEI not found: #{lei_str}" if records.empty?

    record = records.first
    attrs = record.dig('attributes', 'entity') || {}
    {
      lei: lei_str,
      name: attrs.dig('legalName', 'name'),
      jurisdiction: attrs['jurisdiction'],
      legal_form: attrs.dig('legalForm', 'id'),
      status: record.dig('attributes', 'registration', 'status'),
      address: format_address(attrs['legalAddress']),
      initial_registration: record.dig('attributes', 'registration', 'initialRegistrationDate'),
      last_update: record.dig('attributes', 'registration', 'lastUpdateDate')
    }
  end

  private

  # GLEIF allows ~60 requests per minute.
  def rate_limit!
    if @last_request_at
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_request_at
      sleep(1.0 - elapsed) if elapsed < 1.0
    end
    @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def get(path)
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/vnd.api+json'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    case response
    when Net::HTTPSuccess then response
    when Net::HTTPTooManyRequests then raise "Rate limited by GLEIF API. Max ~60 requests/minute."
    else raise "GLEIF API error (#{response.code}): #{response.body}"
    end
  end

  def format_address(addr)
    return nil unless addr

    parts = [
      addr.dig('addressLines')&.join(', '),
      addr['city'],
      addr['region'],
      addr['postalCode'],
      addr['country']
    ]
    parts.compact.reject(&:empty?).join(', ')
  end
end
```

## Usage with sec_id

Validate with SecID, then pass the identifier to the adapter:

```ruby
adapter = GleifAdapter.new

# validate! raises SecID::Error on invalid input, returns the instance on success
lei = SecID::LEI.validate!('7LTWFZYICNSX8D621K86')
lei.to_pretty_s  # => "7LTW FZYI CNSX 8D62 1K86"
lei.lou_id       # => "7LTW"
lei.check_digit  # => 86

result = adapter.lookup(lei.to_s)
puts "#{result[:name]} (#{result[:jurisdiction]})"
puts "Status: #{result[:status]}"
```

## Rate Limiting

GLEIF allows approximately **60 requests per minute**. The API returns HTTP 429 when exceeded.

Simple throttling:

```ruby
# Sleep 1 second between requests
sleep 1.0
```

## Caching

- **Entity data** (name, jurisdiction, legal form): cache for 24 hours
- **Registration status:** cache for 1 hour (status changes are infrequent but important)
- **Addresses:** cache for 24 hours

LEI registrations are renewed annually, so data is relatively stable.

## Error Handling

| Scenario | Response |
|---|---|
| LEI not found | HTTP 200 with empty `data` array |
| Invalid filter | HTTP 400 |
| Rate limited | HTTP 429 |
| Server error | HTTP 500 |

The GLEIF API uses [JSON:API](https://jsonapi.org/) format. Errors are returned in an `errors` array:

```json
{
  "errors": [
    {
      "status": "400",
      "title": "Bad Request",
      "detail": "Invalid filter parameter"
    }
  ]
}
```

## Runnable Example

See [`examples/gleif_lookup.rb`](../../examples/gleif_lookup.rb) for a self-contained script.
