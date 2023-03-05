require 'docker_registry2'
require 'json'
require 'net/http'
require 'redis'
require 'sinatra'
require 'uri'
require 'yaml'

require './github'

[
  'GITHUB_TOKEN',
  'REDIS_URL'
].each do |var|
  if ENV[var].nil? || ENV[var].empty?
    puts "Missing env var: #{var}"
    exit -1
  end
end

set :ndk_info, YAML.load_file('ndk_info.yml')
set :icon_cache, Hash.new
set :github_client, Github.new(ENV['GITHUB_TOKEN'])
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
      settings.redis_client.expire('tags', 300)

      return tags
    end

    JSON.parse(data)
  end

  def tag_built?(ndk, platform, toolchain)
    tags_data["tags"].include?([ndk, platform, toolchain].join('--'))
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
  locals = {
    github: {
      busy: settings.github_client.active_workflow_runs?
    },
    twidth: 7
  }

  erb :index, locals: locals
end

get '/build/:ndk/:platform/:toolchain' do
  locals = {
    github: {
      busy: settings.github_client.active_workflow_runs?
    }
  }

  if settings.github_client.active_workflow_runs?
    locals[:flash] = :github_busy_warning
  end

  erb :build, locals: locals
end

post '/build/:ndk/:platform/:toolchain' do
  locals = {
    github: {
      busy: settings.github_client.active_workflow_runs?
    }
  }

  if settings.github_client.active_workflow_runs?
    locals[:flash] = :github_busy_error
  else
    begin
      # TODO: Sanitize this

      res = settings.github_client.trigger_build(
        ndk: params[:ndk],
        platform: params[:platform],
        toolchain: params[:toolchain],
        tag: [
          params[:ndk],
          params[:platform],
          params[:toolchain]
        ].join("--")
      )

      locals[:github][:busy] = true

      case res
      when Net::HTTPSuccess, Net::HTTPRedirection
        locals[:flash] = :github_build_started
      when Net::HTTPTooManyRequests
        locals[:flash] = :github_rate_limit
      else
        locals[:flash] = :unknown_error
      end
    rescue Net::HTTPServerException, Net::HTTPError => e
      puts e
      locals[:flash] = :unknown_error
    end
  end

  erb :build, locals: locals
end
