require 'sinatra'
require 'travis'
require 'net/http'
require 'uri'
require 'json'
require 'yaml'
require 'docker_registry2'
require 'redis'

require './trigger_build'

[
  'TRAVIS_TOKEN',
  'REDIS_URL'
].each do |var|
  if ENV[var].nil?
    puts "Missing env var: #{var}"
    exit -1
  end
end

set :ndk_info, YAML.load_file('ndk_info.yml')
set :icon_cache, Hash.new
set :travis_client, Travis::Client.new(access_token: ENV['TRAVIS_TOKEN'])
set :dhub_client, DockerRegistry2.connect()
set :redis_client, Redis.new(url: ENV['REDIS_URL'])

helpers do
  def current_page?(path = '')
    request.path_info == "/#{path}"
  end

  def partial(page, options={})
    erb page, options.merge!(:layout => false)
  end

  def render_flash(type)
    partial(:"partials/#{type}")
  end

  def tags_data
    data = settings.redis_client.get('tags')

    if data.nil?
      begin
        tags = settings.dhub_client.tags('rhardih/stand')
      rescue RestClient::NotFound => e
        tags = { "tags" => [] }
      end

      settings.redis_client.set('tags', tags.to_json)
      settings.redis_client.expire('tags', 60)

      return tags
    end

    JSON.parse(data)
  end

  def tag_built?(ndk, platform, toolchain)
    tags_data["tags"].include?([ndk, platform, toolchain].join('--'))
  end

  def travis_busy?
    settings.travis_client.repo('rhardih/stand').builds.any?(&:yellow?)
  end

  def production?
    ENV['RACK_ENV'] == 'production'
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
  settings.travis_client.clear_cache

  locals = {
    travis: {
      busy: travis_busy?
    },
    twidth: 7
  }

  erb :index, locals: locals
end

get '/build/:ndk/:platform/:toolchain' do
  settings.travis_client.clear_cache

  locals = {
    travis: {
      busy: travis_busy?
    }
  }

  if travis_busy?
    locals[:flash] = :travis_busy_warning
  end

  erb :build, locals: locals
end

post '/build/:ndk/:platform/:toolchain' do
  settings.travis_client.clear_cache

  locals = {
    travis: {
      busy: travis_busy?
    }
  }

  if travis_busy?
    locals[:flash] = :travis_busy_error
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
          params[:platform],
          params[:toolchain]
        ].join("--")
      )

      locals[:travis][:busy] = true

      case res
      when Net::HTTPSuccess, Net::HTTPRedirection
        locals[:flash] = :travis_build_started
        settings.travis_client.clear_cache
      when Net::HTTPTooManyRequests
        locals[:flash] = :travis_rate_limit
      else
        p res
        locals[:flash] = :unknown_error
      end
    rescue Net::HTTPServerException => e
      locals[:flash] = :unknown_error
    end
  end

  erb :build, locals: locals
end
