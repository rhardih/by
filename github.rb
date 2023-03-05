require 'net/http'
require 'json'

# curl -H "Accept: application/vnd.github.everest-preview+json" \
#     -H "Authorization: token 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" \
#       --request POST \
#         --data '{"event_type": "on-demand-build-image", "client_payload": {"ndk": "r11c", "platform": "android-21", "toolchain": "arm-linux-androideabi-4.9" } }' \
#           https://api.github.com/repos/rhardih/stand/dispatches


# curl -L   -H "Accept: application/vnd.github+json"   -H "Authorization: Bearer
# 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"  -H "X-GitHub-Api-Version:
# 2022-11-28"   https://api.github.com/repos/rhardih/stand/actions/runs

class Github
  attr_reader :base_uri
  attr_reader :base_headers

  def initialize(token)
    @base_uri = 'https://api.github.com/repos/rhardih/stand'
    @base_headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/vnd.github+json',
      'Authorization' => "token #{token}"
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

    req = Net::HTTP::Get.new(uri, base_headers)

    response = http.request(req)

    unless response.is_a?(Net::HTTPSuccess)
      raise HttpError.new(response.code, response.message)
    end

    parsed = JSON.parse(response.body)

    parsed["workflow_runs"].any? { |workflow| workflow["status"] == "in_progress" }
  end
end
