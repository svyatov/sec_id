#!/usr/bin/env ruby
# frozen_string_literal: true

# Eurex Lookup Example
#
# Looks up derivative product data by ISIN using the Eurex Reference Data GraphQL API.
# Requires only stdlib (net/http, json) plus the sec_id gem.
#
# Usage:
#   ruby examples/eurex_lookup.rb
#
# Note: This API covers Eurex-listed derivatives only. Equity ISINs like
# US5949181045 will not return results — use a derivative ISIN instead.
#
# See: https://www.eurex.com/ex-en/data/free-reference-data-api

require 'sec_id'
require 'net/http'
require 'json'

class EurexAdapter
  BASE_URL = 'https://api.developer.deutsche-boerse.com'
  GRAPHQL_ENDPOINT = '/eurex-prod-graphql/'

  # The shared public API key for anonymous access.
  DEFAULT_API_KEY = '68cdafd2-c5c1-49be-8558-37244ab4f513'

  def initialize(api_key: nil)
    @api_key = api_key || DEFAULT_API_KEY
  end

  # Look up a derivative product by ISIN.
  #
  # @param isin_str [String] a validated ISIN for a Eurex-listed derivative
  # @return [Hash] product data
  # @raise [RuntimeError] on API errors
  def lookup(isin_str)
    query = build_query(isin_str)
    response = post(GRAPHQL_ENDPOINT, query)
    data = JSON.parse(response.body)

    parse_products(data, isin_str)
  end

  private

  def build_query(isin)
    {
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
  end

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
    when Net::HTTPUnauthorized
      raise 'Eurex API authentication failed. Check your API key.'
    else
      raise "Eurex API error (#{response.code}): #{response.body}"
    end
  end

  def parse_products(data, isin_str)
    errors = data['errors']
    raise "Eurex GraphQL error: #{errors.map { |e| e['message'] }.join(', ')}" if errors&.any?

    product_infos = data.dig('data', 'ProductInfos') || {}
    products = (product_infos['data'] || []).map do |prod|
      { product_id: prod['Product'], name: prod['Name'], isin: prod['ProductISIN'],
        product_line: prod['ProductLine'], product_type: prod['ProductType'] }
    end
    { isin: isin_str, date: product_infos['date'], products: products }
  end
end

# --- Demo ---

if __FILE__ == $PROGRAM_NAME
  # Validate with SecID before calling the API
  isin = SecID::ISIN.validate!('DE0009652644')
  puts "ISIN:         #{isin}"
  puts "Formatted:    #{isin.to_pretty_s}"
  puts "Country:      #{isin.country_code}"
  puts "NSIN type:    #{isin.nsin_type}"
  puts "Check digit:  #{isin.check_digit}"
  puts

  begin
    adapter = EurexAdapter.new
    result = adapter.lookup(isin.to_s)
    puts "Data date: #{result[:date]}"
    if result[:products].empty?
      puts "No products found for #{isin_str}"
    else
      puts "Found #{result[:products].size} product(s):"
      result[:products].each do |prod|
        puts "  Product ID:   #{prod[:product_id]}"
        puts "  Name:         #{prod[:name]}"
        puts "  ISIN:         #{prod[:isin]}"
        puts "  Product Line: #{prod[:product_line]}"
        puts "  Product Type: #{prod[:product_type]}"
        puts
      end
    end
  rescue StandardError => e
    puts "Error: #{e.message}"
  end
end
