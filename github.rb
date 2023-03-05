require 'net/http'
require 'json'

class Github
  attr_reader :base_uri
  attr_reader :base_headers

  def initialize(token)
    @base_uri = 'https://api.github.com/repos/rhardih/stand'
    @base_headers = {
      'Accept' => 'application/vnd.github+json',
      'Authorization' => "Bearer #{token}",
      'X-GitHub-Api-Version' => '2022-11-28'
    }
  end

  def trigger_build(ndk:, platform:, toolchain:, tag:)
    uri = URI("#{base_uri}/dispatches")

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new(uri, base_headers)

    if ndk.nil?
      puts "TriggerBuild: ndk required"
      exit
    end

    payload = {
      event_type: "on-demand-build-image",
      client_payload: {
        ndk: ndk,
        platform: platform,
        toolchain: toolchain
      }
    }

    req.body = payload.to_json

    http.request(req)
  end

  def active_workflow_runs?
    uri = URI("#{base_uri}/actions/runs")

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true

    p base_headers

    req = Net::HTTP::Get.new(uri, base_headers)

    response = http.request(req)

    unless response.is_a?(Net::HTTPSuccess)
      raise Net::HTTPError.new(response.code, response.message)
    end

    parsed = JSON.parse(response.body)

    parsed["workflow_runs"].any? { |workflow| workflow["status"] == "in_progress" }
  end
end
