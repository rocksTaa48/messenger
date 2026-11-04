#!/bin/sh
set -e

# Ждем базу
while ! nc -z postgres 5432; do sleep 0.5; done

echo "=== Creating Database if not exists ==="
/messenger/bin/messenger eval "Messenger.Release.create()"

echo "=== Running Ecto Migrations ==="
/messenger/bin/messenger eval "Messenger.Release.migrate()"

if [ ! -f /state/seeded ]; then
  echo "=== First run, seeding database ==="
  /messenger/bin/messenger eval "Messenger.Release.seed()"
  touch /state/seeded
else
  echo "=== Already seeded, skipping ==="
fi

echo "=== Starting Phoenix Server ==="
exec /messenger/bin/messenger start

