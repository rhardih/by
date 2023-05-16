FROM ruby:3.2.1-alpine

RUN apk update && apk add build-base

WORKDIR /by

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY app.rb github.rb ndk_info.yml config.ru .
COPY views ./views
COPY public ./public

RUN gem install rerun

EXPOSE 4567

CMD ["rerun", "--background", "bundle exec rackup --host 0.0.0.0 -p 4567"]
