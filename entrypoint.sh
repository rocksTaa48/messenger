#!/bin/sh
set -e

# Ждем базу
while ! nc -z postgres 5432; do sleep 0.5; done

echo "=== Running Ecto Migrations ==="
/messenger/bin/messenger eval "Messenger.Release.migrate()"

echo "=== Running Database Seeds ==="
/messenger/bin/messenger eval "Messenger.Release.seed()"

echo "=== Starting Phoenix Server ==="
exec /messenger/bin/messenger start

