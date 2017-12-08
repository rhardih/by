require 'sinatra'
require 'travis'
require 'net/http'
require 'uri'
require 'json'
require 'yaml'

require './trigger_build'

if ENV['TRAVIS_TOKEN'].nil?
  puts "Missing TRAVIS_TOKEN"
  exit -1
end

Travis.access_token = ENV['TRAVIS_TOKEN']
client = Travis::Client.new

set :ndk_info, YAML.load_file('ndk_info.yml')
set :icon_cache, Hash.new

helpers do
  def current_page?(path = '')
    request.path_info == "/#{path}"
  end

  def method_missing(id, *args, &block)
    if id =~ /svg_/
      # memoize file reads
      settings.icon_cache[args.first] ||=
        File.read(File.join('public', 'images', args.first))
    else
      super
    end
  end
end

get '/' do
  erb :index, locals: { twidth: 7 }
end

get '/build/:ndk/:platform/:toolchain' do
  stand = client.repo('rhardih/stand')

  travis_busy = stand.builds.any? { |b| b.pending? }

  locals = {
    travis: {
      busy: travis_busy
    }
  }

  if travis_busy

    locals[:flash] = {
      type: :warning,
      message: "<label><strong>Warning</strong></label>: It seems Travis is already busy building a container, at the moment.  Please check the build progress and try again, when it's done.  <a href='https://travis-ci.org/rhardih/stand/builds'>https://travis-ci.org/rhardih/stand/builds</a>"
    }
  end

  erb :build, locals: locals
end

post '/build/:ndk/:platform/:toolchain' do
  stand = client.repo('rhardih/stand')

  travis_busy = stand.builds.any? { |b| b.pending? }

  locals = {
    travis: {
      busy: travis_busy
    }
  }

  if travis_busy
    locals[:flash] = {
      type: :warning,
      message: "<label><strong>Warning</strong></label>: Build not started. Travis is already busy building."
    }
  else

    begin
      # TODO: Sanitize this

      ndk_url = settings.ndk_info[params[:ndk]]["url"]
      ndk_sha = settings.ndk_info[params[:ndk]]["sha"]

      res = TriggerBuild.call(
        ndk_url: ndk_url,
        ndk_sha: ndk_sha,
        platform: params[:platform],
        toolchain: params[:toolchain],
        tag: [
          params[:ndk],
          params[:platform].gsub(/ndroid-/, ""),
          params[:toolchain]
        ].join("-")
      )

      case res
      when Net::HTTPSuccess, Net::HTTPRedirection
        locals[:flash] = {
          type: :success,
          message: "<label><strong>Success</strong></label>: Build successfully started on Travis."
        }

        locals[:travis][:busy]
      else
        locals[:flash] = {
          type: :warning,
          message: "<label><strong>Warning</strong></label>: Something happened. #{res.value}"
        }
      end
    rescue Net::HTTPServerException => e
      locals[:flash] = {
        type: :error,
        message: "<label><strong>Error</strong></label>: Build not started on Travis. #{e}"
      }
    end
  end

  erb :build, locals: locals
end
