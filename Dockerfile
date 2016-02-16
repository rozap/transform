FROM ubuntu:14.04
MAINTAINER Chris Duranti <chris.duranti@socrata.com>
RUN apt-get install -y wget
RUN wget http://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && dpkg -i erlang-solutions_1.0_all.deb
RUN apt-get update
RUN apt-get install -y elixir erlang-parsetools erlang-dev git build-essential erlang-appmon erlang-asn1 erlang-base erlang-crypto erlang-dev erlang-et erlang-gs erlang-inets erlang-mnesia erlang-observer erlang-parsetools erlang-public-key erlang-runtime-tools erlang-solutions erlang-ssl erlang-syntax-tools erlang-wx erlang-webtool erlang-xmerl

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8


ENV MIX_ENV prod

WORKDIR /app

ADD lib /app/lib
ADD config /app/config
ADD web /app/web
ADD priv /app/priv

ADD mix.lock /app/
ADD mix.exs /app/
ADD package.json /app/
ADD brunch-config.js /app/

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN mix compile
RUN mix phoenix.digest

