FROM ruby:3.2.1-alpine

RUN apk update && apk add \
  build-base \
  libxml2-dev \
  libxslt-dev \
  postgresql-dev \
  && rm -rf /var/cache/apk/*

WORKDIR /by

COPY Gemfile Gemfile.lock ./

RUN bundle config build.nokogiri --use-system-libraries

RUN bundle install

COPY app.rb github.rb ndk_info.yml config.ru .
COPY views ./views
COPY public ./public

EXPOSE 4567

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]
