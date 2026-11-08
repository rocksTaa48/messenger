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

RUN apk add --no-cache build-base git vips-dev

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
# ЭТАП 3: Минимальный образ для запуска
# ==========================================
FROM alpine:3.23.7

# Устанавливаем необходимые зависимости для работы Erlang
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    tzdata \
    vips \
    libjpeg-turbo \
    libpng \
    libwebp

# Фиксируем рабочую директорию
WORKDIR /messenger

# Копируем собранный релиз из Второго этапа (пока мы под root)
COPY --from=elixir-builder /messenger/_build/prod/rel/messenger ./

# Копируем скрипт
COPY entrypoint.sh ./

# Делаем скрипт исполняемым и отдаем всю папку пользователю nobody
RUN chmod +x entrypoint.sh && chown -R nobody:root /messenger

# Безопасность: теперь переключаемся на системного пользователя 'nobody'
USER nobody

# Настраиваем домашнюю директорию для Erlang/Phoenix
ENV HOME=/messenger

# Теперь контейнер при старте выполнит entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
