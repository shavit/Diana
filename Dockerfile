from elixir:1.5.1-alpine

RUN mkdir -p /var/www/diana
WORKDIR /var/www/diana

RUN mix local.hex --force && mix local.rebar --force

COPY bin/ffmpeg /var/www/diana/bin
ADD mix.exs /var/www/diana/
ADD mix.lock /var/www/diana/
RUN mix deps.get

ADD . /var/www/diana
RUN mix compile