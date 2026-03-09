FROM elixir:1.17

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app

COPY mix.exs mix.lock ./
COPY config ./config
COPY apps/audit/mix.exs ./apps/audit/mix.exs
COPY apps/policy/mix.exs ./apps/policy/mix.exs
COPY apps/providers/mix.exs ./apps/providers/mix.exs
COPY apps/resources/mix.exs ./apps/resources/mix.exs
COPY apps/runtime/mix.exs ./apps/runtime/mix.exs
COPY apps/gateway/mix.exs ./apps/gateway/mix.exs

RUN mix deps.get

COPY . .

RUN mix deps.get && mix compile

CMD ["mix", "run", "--no-halt"]
