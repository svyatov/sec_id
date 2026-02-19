# Eurex Reference Data API Integration

Look up Eurex-listed derivative products by ISIN using the [Eurex Reference Data GraphQL API](https://www.eurex.com/ex-en/data/free-reference-data-api).

## Service Overview

Eurex provides free reference data for its listed derivatives via a GraphQL API. The API covers products, contracts, trading hours, and expirations. Use it to look up derivative product metadata by ISIN, product code, or name.

- **API portal:** https://console.developer.deutsche-boerse.com/apis
- **Product page:** https://www.eurex.com/ex-en/data/free-reference-data-api

**Important:** This API covers Eurex-listed derivatives only (futures, options). Equity ISINs will not return results.

## Authentication

A shared public API key is available for anonymous access:

```
X-DBP-APIKEY: 68cdafd2-c5c1-49be-8558-37244ab4f513
```

For higher throughput, register for a dedicated key at the [Deutsche Boerse developer portal](https://console.developer.deutsche-boerse.com/apis).

## Adapter

```ruby
require 'sec_id'
require 'net/http'
require 'json'

class EurexAdapter
  BASE_URL = 'https://api.developer.deutsche-boerse.com'
  GRAPHQL_ENDPOINT = '/eurex-prod-graphql/'

  DEFAULT_API_KEY = '68cdafd2-c5c1-49be-8558-37244ab4f513'

  def initialize(api_key: nil)
    @api_key = api_key || DEFAULT_API_KEY
  end

  # Look up a derivative product by ISIN.
  #
  # @param isin_str [String] an ISIN for a Eurex-listed derivative
  # @return [Hash] product data
  # @param isin_str [String] a validated ISIN for a Eurex-listed derivative
  def lookup(isin_str)
    query = {
      query: <<~GRAPHQL
        query {
          ProductInfos(filter: { ProductISIN: { eq: "#{isin}" } }) {
            date
            data {
              Product
              Name
              ProductISIN
              ProductLine
              ProductType
            }
          }
        }
      GRAPHQL
    }

    response = post(GRAPHQL_ENDPOINT, query)
    data = JSON.parse(response.body)

    errors = data['errors']
    raise "Eurex GraphQL error: #{errors.map { |e| e['message'] }.join(', ')}" if errors&.any?

    products = data.dig('data', 'ProductInfos', 'data') || []
    {
      isin: isin_str,
      date: data.dig('data', 'ProductInfos', 'date'),
      products: products.map { |prod|
        {
          product_id: prod['Product'],
          name: prod['Name'],
          isin: prod['ProductISIN'],
          product_line: prod['ProductLine'],
          product_type: prod['ProductType']
        }
      }
    }
  end

  private

  def post(path, body)
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    request['X-DBP-APIKEY'] = @api_key
    request.body = JSON.generate(body)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    case response
    when Net::HTTPSuccess then response
    when Net::HTTPUnauthorized then raise 'Eurex API authentication failed. Check your API key.'
    else raise "Eurex API error (#{response.code}): #{response.body}"
    end
  end
end
```

## Usage with sec_id

Validate with SecID, then pass the identifier to the adapter:

```ruby
adapter = EurexAdapter.new

# validate! raises SecID::Error on invalid input, returns the instance on success
isin = SecID::ISIN.validate!('DE0009652644')
isin.to_pretty_s  # => "DE 000965264 4"
isin.country_code # => "DE"
isin.nsin_type    # => :wkn

result = adapter.lookup(isin.to_s)
result[:products].each do |prod|
  puts "#{prod[:product_id]}: #{prod[:name]} (#{prod[:product_type]})"
end
```

## Available Queries

The GraphQL API supports several root queries beyond `ProductInfos`:

```graphql
# Look up contracts by product code
query {
  Contracts(filter: { Product: { eq: "FGBL" } }) {
    date
    data { Product, Contract, PreviousDaySettlementPrice }
  }
}

# Search products by name
query {
  ProductInfos(filter: { Name: { contains: "Bund" } }) {
    date
    data { Product, Name, ProductISIN, ProductType }
  }
}
```

Use GraphQL introspection to discover all available fields:

```graphql
query {
  __schema { queryType { fields { name description } } }
}
```

## Rate Limiting

The shared API key has undisclosed rate limits. For production use, register a dedicated key. The API does not return rate-limit headers.

Simple throttling for the shared key:

```ruby
# Conservative: 1 second between requests
sleep 1.0
```

## Caching

- **Product metadata** (name, type, product line): cache for 24 hours
- **Contract data** (settlement prices): cache for 1 hour (updates daily)
- **Trading hours/holidays:** cache for 24 hours

## Error Handling

| Scenario | Response |
|---|---|
| Product not found | HTTP 200 with empty `data` array |
| Invalid query | HTTP 200 with `errors` array |
| Bad API key | HTTP 401 |
| Server error | HTTP 500 |

GraphQL errors are returned in the response body even with HTTP 200:

```json
{
  "errors": [
    { "message": "Cannot query field 'invalid' on type 'ProductInfo'" }
  ]
}
```

## Runnable Example

See [`examples/eurex_lookup.rb`](../../examples/eurex_lookup.rb) for a self-contained script.
