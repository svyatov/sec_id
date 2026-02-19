#!/usr/bin/env ruby
# frozen_string_literal: true

# SEC EDGAR Lookup Example
#
# Looks up company filing data by CIK using the SEC EDGAR API.
# Requires only stdlib (net/http, json) plus the sec_id gem.
#
# Usage:
#   ruby examples/sec_edgar_lookup.rb
#
# Note: SEC EDGAR requires a User-Agent header with your app name and email.
# See: https://www.sec.gov/os/accessing-edgar-data

require 'sec_id'
require 'net/http'
require 'json'

class SecEdgarAdapter
  BASE_URL = 'https://data.sec.gov'

  # @param user_agent [String] required "AppName contact@email.com" format
  def initialize(user_agent:)
    if user_agent.nil? || user_agent.empty?
      raise ArgumentError,
            'user_agent is required (e.g. "MyApp admin@example.com")'
    end

    @user_agent = user_agent
    @last_request_at = nil
  end

  # Look up a company by CIK number (must be zero-padded to 10 digits).
  #
  # @param padded_cik [String] a 10-digit CIK (e.g. "0001521365")
  # @return [Hash] company data including name, tickers, and recent filings
  # @raise [RuntimeError] on API errors
  def lookup(padded_cik)
    padded = padded_cik
    rate_limit!

    response = get("/submissions/CIK#{padded}.json")
    data = JSON.parse(response.body)

    parse_submission(data, padded)
  end

  private

  # SEC EDGAR allows 10 requests per second. Sleep to stay under the limit.
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

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    handle_response(response)
  end

  def handle_response(response)
    case response
    when Net::HTTPSuccess then response
    when Net::HTTPNotFound then raise 'CIK not found at SEC EDGAR'
    when Net::HTTPTooManyRequests then raise 'Rate limited by SEC EDGAR. Max 10 requests/second.'
    else raise "SEC EDGAR API error (#{response.code}): #{response.body}"
    end
  end

  def parse_submission(data, cik)
    {
      cik: cik, name: data['name'],
      tickers: data['tickers'] || [], exchanges: data['exchanges'] || [],
      sic: data['sic'], sic_description: data['sicDescription'],
      state: data['stateOfIncorporation'],
      recent_filings: parse_recent_filings(data.dig('filings', 'recent') || {})
    }
  end

  def parse_recent_filings(recent)
    (recent['form'] || []).take(5).each_with_index.map do |form, i|
      { form: form, date: recent['filingDate']&.at(i), description: recent['primaryDocDescription']&.at(i) }
    end
  end
end

# --- Demo ---

if __FILE__ == $PROGRAM_NAME
  # Validate and normalize with SecID before calling the API
  cik = SecID::CIK.validate!(SecID::CIK::EXAMPLE)
  padded = cik.normalized # zero-pads to 10 digits, exactly what EDGAR expects
  puts "CIK:        #{cik}"
  puts "Normalized: #{padded}"
  puts

  begin
    adapter = SecEdgarAdapter.new(user_agent: 'SecIdExample admin@example.com')
    result = adapter.lookup(padded)
    puts "Company:  #{result[:name]}"
    puts "Tickers:  #{result[:tickers].join(', ')}" unless result[:tickers].empty?
    puts "Exchange: #{result[:exchanges].join(', ')}" unless result[:exchanges].empty?
    puts "SIC:      #{result[:sic]} - #{result[:sic_description]}"
    puts "State:    #{result[:state]}"
    puts
    puts 'Recent filings:'
    result[:recent_filings].each do |filing|
      puts "  #{filing[:date]}  #{filing[:form]}  #{filing[:description]}"
    end
  rescue StandardError => e
    puts "Error: #{e.message}"
  end
end
