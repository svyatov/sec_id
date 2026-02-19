#!/usr/bin/env ruby
# frozen_string_literal: true

# GLEIF Lookup Example
#
# Looks up legal entity data by LEI using the GLEIF API v1.
# Requires only stdlib (net/http, json) plus the sec_id gem.
#
# Usage:
#   ruby examples/gleif_lookup.rb
#
# No authentication required. Rate limit: ~60 requests/minute.
# See: https://www.gleif.org/en/lei-data/gleif-api

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
  # @param lei_str [String] a LEI (e.g. "7LTWFZYICNSX8D621K86")
  # @return [Hash] entity data including name, jurisdiction, status
  # @raise [SecID::Error] if the LEI is invalid
  # @raise [RuntimeError] on API errors
  def lookup(lei_str)
    lei = SecID::LEI.validate!(lei_str)
    rate_limit!
    response = get("/lei-records?filter[lei]=#{lei}")
    data = JSON.parse(response.body)

    parse_lei_record(data, lei.to_s)
  end

  private

  # GLEIF allows ~60 requests per minute. Sleep 1 second between requests.
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
    when Net::HTTPTooManyRequests
      raise 'Rate limited by GLEIF API. Max ~60 requests/minute.'
    else
      raise "GLEIF API error (#{response.code}): #{response.body}"
    end
  end

  def parse_lei_record(data, lei_str)
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

  def format_address(addr)
    return nil unless addr

    parts = [
      addr['addressLines']&.join(', '),
      addr['city'],
      addr['region'],
      addr['postalCode'],
      addr['country'],
    ]
    parts.compact.reject(&:empty?).join(', ')
  end
end

# --- Demo ---

if __FILE__ == $PROGRAM_NAME
  adapter = GleifAdapter.new

  # Use the LEI example from sec_id
  lei_str = SecID::LEI::EXAMPLE # "7LTWFZYICNSX8D621K86"
  puts "Looking up LEI: #{lei_str}"
  puts

  begin
    result = adapter.lookup(lei_str)
    puts "Entity:       #{result[:name]}"
    puts "Jurisdiction: #{result[:jurisdiction]}"
    puts "Legal Form:   #{result[:legal_form]}"
    puts "Status:       #{result[:status]}"
    puts "Address:      #{result[:address]}"
    puts "Registered:   #{result[:initial_registration]}"
    puts "Last Update:  #{result[:last_update]}"
  rescue StandardError => e
    puts "Error: #{e.message}"
  end
end
