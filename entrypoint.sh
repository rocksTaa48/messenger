#!/bin/sh
set -e

# Ждем, пока база данных PostgreSQL встанет
echo "Waiting for database to be ready..."
while ! nc -z db 5432; do
  sleep 0.5
done
echo "Database is ready!"

# Накатываем миграции
echo "Running migrations..."
/app/bin/messenger migrate

# Запускаем само приложение Phoenix
echo "Starting Phoenix server..."
exec /app/bin/messenger start
