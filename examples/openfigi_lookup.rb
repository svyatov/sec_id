#!/usr/bin/env ruby
# frozen_string_literal: true

# OpenFIGI Lookup Example
#
# Looks up financial instrument data by FIGI using the OpenFIGI API v3.
# Requires only stdlib (net/http, json) plus the sec_id gem.
#
# Usage:
#   ruby examples/openfigi_lookup.rb
#   OPENFIGI_API_KEY=your-key ruby examples/openfigi_lookup.rb

require 'sec_id'
require 'net/http'
require 'json'

class OpenFigiAdapter
  BASE_URL = 'https://api.openfigi.com'
  MAPPING_ENDPOINT = '/v3/mapping'

  def initialize(api_key: nil)
    @api_key = api_key || ENV.fetch('OPENFIGI_API_KEY', nil)
  end

  # Look up a single FIGI identifier.
  #
  # @param figi_str [String] a validated FIGI string (e.g. "BBG000BLNNH6")
  # @return [Hash] parsed instrument data
  # @raise [RuntimeError] on API errors
  def lookup(figi_str)
    body = [{ idType: 'ID_BB_GLOBAL', idValue: figi_str }]
    response = post(MAPPING_ENDPOINT, body)
    result = JSON.parse(response.body)

    parse_single_result(result, figi_str)
  end

  # Look up multiple FIGIs in a single batch request (max 100).
  #
  # @param figi_strings [Array<String>] validated FIGI strings
  # @return [Array<Hash>] parsed results per FIGI
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

  def parse_single_result(result, figi_str)
    entry = result.first
    raise "FIGI not found: #{figi_str} (#{entry['error']})" if entry.key?('error')

    instruments = entry.fetch('data', [])
    { figi: figi_str, instruments: instruments.map { |inst| parse_instrument(inst) } }
  end

  def parse_instrument(inst)
    {
      name: inst['name'],
      ticker: inst['ticker'],
      exchange: inst['exchCode'],
      security_type: inst['securityType'],
      market_sector: inst['marketSector']
    }
  end
end

# --- Demo ---

if __FILE__ == $PROGRAM_NAME
  # Validate with SecID before calling the API
  figi = SecID::FIGI.validate!(SecID::FIGI::EXAMPLE)
  puts "FIGI:        #{figi}"
  puts "Formatted:   #{figi.to_pretty_s}"
  puts "Check digit: #{figi.check_digit}"
  puts

  begin
    adapter = OpenFigiAdapter.new
    result = adapter.lookup(figi.to_s)
    puts "Found #{result[:instruments].size} instrument(s):"
    result[:instruments].each do |inst|
      puts "  Name:     #{inst[:name]}"
      puts "  Ticker:   #{inst[:ticker]}"
      puts "  Exchange: #{inst[:exchange]}"
      puts "  Type:     #{inst[:security_type]}"
      puts "  Sector:   #{inst[:market_sector]}"
      puts
    end
  rescue StandardError => e
    puts "Error: #{e.message}"
  end
end
