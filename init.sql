-- Считываем переменные окружения Docker в переменные psql
\set elixir_user `echo "$ELIXIR_DB_USER"`
\set elixir_password `echo "$ELIXIR_DB_PASSWORD"`

-- Создаем пользователя для Elixir и даем ему право создавать базы данных CREATEDB
CREATE USER :elixir_user WITH CREATEDB PASSWORD :'elixir_password';