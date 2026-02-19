# SEC EDGAR API Integration

Look up SEC filing entities by CIK using the [SEC EDGAR API](https://www.sec.gov/edgar/sec-api-documentation).

## Service Overview

SEC EDGAR (Electronic Data Gathering, Analysis, and Retrieval) provides free access to company filings, ownership data, and entity information. The submissions endpoint returns entity metadata and recent filings for a given CIK.

- **Official docs:** https://www.sec.gov/edgar/sec-api-documentation
- **Accessing EDGAR data:** https://www.sec.gov/os/accessing-edgar-data

## Authentication

No API key required. However, SEC **requires a `User-Agent` header** identifying your application and contact email:

```
User-Agent: MyApp admin@example.com
```

Requests without this header will be blocked.

## Adapter

```ruby
require 'sec_id'
require 'net/http'
require 'json'

class SecEdgarAdapter
  BASE_URL = 'https://data.sec.gov'

  # @param user_agent [String] required "AppName contact@email.com" format
  def initialize(user_agent:)
    raise ArgumentError, 'user_agent is required' if user_agent.nil? || user_agent.empty?

    @user_agent = user_agent
    @last_request_at = nil
  end

  # Look up a company by CIK number.
  #
  # @param cik_str [String, Integer]
  # @return [Hash] company data including name, tickers, and recent filings
  def lookup(cik_str)
    cik = SecID::CIK.validate!(cik_str.to_s)
    padded = cik.normalized # zero-padded to 10 digits
    rate_limit!

    response = get("/submissions/CIK#{padded}.json")
    data = JSON.parse(response.body)

    recent = data.dig('filings', 'recent') || {}
    {
      cik: padded,
      name: data['name'],
      tickers: data['tickers'] || [],
      exchanges: data['exchanges'] || [],
      sic: data['sic'],
      sic_description: data['sicDescription'],
      state: data['stateOfIncorporation'],
      recent_filings: (recent['form'] || []).take(5).each_with_index.map { |form, i|
        {
          form: form,
          date: recent['filingDate']&.at(i),
          description: recent['primaryDocDescription']&.at(i)
        }
      }
    }
  end

  private

  # SEC allows 10 requests per second.
  def rate_limit!
    if @last_request_at
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_request_at
      sleep(0.1 - elapsed) if elapsed < 0.1
    end
    @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def get(path)
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = @user_agent
    request['Accept'] = 'application/json'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    case response
    when Net::HTTPSuccess then response
    when Net::HTTPNotFound then raise "CIK not found at SEC EDGAR"
    when Net::HTTPTooManyRequests then raise "Rate limited by SEC EDGAR. Max 10 requests/second."
    else raise "SEC EDGAR API error (#{response.code}): #{response.body}"
    end
  end
end
```

## Usage with sec_id

`SecID::CIK#normalized` zero-pads the CIK to 10 digits, which is exactly what the EDGAR API expects:

```ruby
adapter = SecEdgarAdapter.new(user_agent: 'MyApp admin@example.com')

# Works with or without leading zeros
result = adapter.lookup('1521365')
result = adapter.lookup('0001521365')

puts result[:name]          # Company name
puts result[:tickers]       # Trading tickers
puts result[:recent_filings] # Last 5 filings
```

## Rate Limiting

SEC EDGAR allows **10 requests per second**. Exceeding this results in temporary IP blocks.

Simple throttling:

```ruby
# Sleep 100ms between requests
sleep 0.1
```

For bulk lookups, consider downloading the [full company index](https://www.sec.gov/Archives/edgar/full-index/) instead of making individual API calls.

## Caching

- **Entity metadata** (name, SIC, state): cache for 24 hours (changes are rare)
- **Recent filings:** cache for 1 hour (new filings appear daily for active filers)
- **Historical filings:** cache indefinitely (they don't change)

## Error Handling

| Scenario | Response |
|---|---|
| CIK not found | HTTP 404 |
| Missing User-Agent | HTTP 403 |
| Rate limited | HTTP 429 or connection refused |
| Server error | HTTP 500 |

SEC EDGAR may silently block your IP if you exceed rate limits without returning a 429. If requests start timing out, back off significantly.

## Runnable Example

See [`examples/sec_edgar_lookup.rb`](../../examples/sec_edgar_lookup.rb) for a self-contained script.
