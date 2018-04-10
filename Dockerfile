FROM elixir

WORKDIR /bittorrent_client/
COPY . /bittorrent_client/

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN mix deps.compile
RUN mix compile
RUN mix test

EXPOSE 8080/tcp
EXPOSE 8080/udp
ENTRYPOINT iex -S mix