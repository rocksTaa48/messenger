# ==========================================
# ЭТАП 1: Сборка Frontend Svelte релиза
# ==========================================
FROM node:26-alpine3.24 AS frontend-builder

WORKDIR /messenger/assets/frontend

# Копируем файлы зависимостей фронтенда для кэширования
COPY assets/frontend/package*.json ./
RUN npm ci

# Копируем весь исходный код фронтенда
COPY assets/frontend/ .

# Собираем Svelte в статичные файлы ../priv/static
RUN npm run build

# ==========================================
# ЭТАП 2: Сборка Elixir релиза
# ==========================================
FROM hexpm/elixir:1.19.7-erlang-28.4.3-alpine-3.23.7 AS elixir-builder

RUN apk add --no-cache build-base git

WORKDIR /messenger

# Устанавливаем Hex и Rebar
RUN mix local.hex --force && mix local.rebar --force

# Устанавливаем окружение PROD
ENV MIX_ENV=prod

# Копируем и собираем зависимости Elixir (кэшируемый слой)
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Копируем конфигурацию
COPY config config

# Копируем фронтенд
COPY --from=frontend-builder /messenger/priv/static ./priv/static

# Копируем остальной код приложения
COPY lib lib
COPY priv priv

# Компилируем приложение и собираем релиз
RUN mix compile
RUN mix release

# ==========================================
# ЭТАП 3: Финальный минимальный образ для запуска
# ==========================================
FROM alpine:3.23.7

# Устанавливаем системные зависимости, необходимые для работы Erlang-рантайма
RUN apk add --no-cache libstdc++ openssl ncurses-libs tzdata

WORKDIR /messenger

# Безопасность: запускаем приложение от имени системного пользователя 'nobody'
RUN chown nobody /messenger
USER nobody

# Копируем собранный релиз из Второго этапа
COPY --from=elixir-builder --chown=nobody:root /messenger/_build/prod/rel/messenger ./

COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh && chown nobody entrypoint.sh

ENV HOME=/messenger

# Теперь контейнер всегда сначала выполнит скрипт
ENTRYPOINT ["./entrypoint.sh"]