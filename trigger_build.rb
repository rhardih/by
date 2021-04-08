require 'net/http'

class TriggerBuild
  def self.call(ndk_url:, ndk_sha:, platform:, toolchain:, tag:)
    uri = URI('https://api.travis-ci.com/repo/rhardih%2Fstand/requests')

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new(uri, {
      'Content-Type' => 'application/json',
      'Travis-API-Version' => '3',
      'Accept' => 'application/json',
      'Authorization' => "token #{ENV['TRAVIS_TOKEN']}"
    })

    if ndk_url.nil? || ndk_sha.nil?
      p "Empty: #{ndk_url} - #{ndk_sha}"
      exit
    end

    build_args = [
      '--build-arg NDK_URL=$NDK_URL',
      '--build-arg NDK_SHA=$NDK_SHA',
      '--build-arg PLATFORM=$PLATFORM',
      '--build-arg TOOLCHAIN=$TOOLCHAIN',
    ].join(' ')

    cmd = [
      'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin',
      "docker build #{build_args} -t rhardih/stand:#{tag} .",
      "docker push rhardih/stand:#{tag}"
    ].join(" && ")

    payload = {
      req: { branch: "master" },
      config: {
        env: {
          "NDK_URL" => ndk_url,
          "NDK_SHA" => ndk_sha,
          "PLATFORM" => platform,
          "TOOLCHAIN" => toolchain
        },
        script: cmd
      }
    }

    req.body = payload.to_json

    http.request(req)
  end
end
