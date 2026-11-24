FROM elixir:1.20

WORKDIR /bittorrent_client/
COPY . /bittorrent_client/

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix deps.compile && \
    mix assets.setup && \
    mix assets.build && \
    mix compile && \
    mix test

EXPOSE 8080/tcp
EXPOSE 8080/udp

EXPOSE 4000/tcp
EXPOSE 4000/udp

ENTRYPOINT ["mix", "phx.server"]
