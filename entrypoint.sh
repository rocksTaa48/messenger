#!/bin/sh
set -e

# Ждем базу
while ! nc -z postgres 5432; do sleep 0.5; done

echo "=== Creating Database if not exists ==="
/messenger/bin/messenger eval "Messenger.Release.create()"

echo "=== Running Ecto Migrations ==="
/messenger/bin/messenger eval "Messenger.Release.migrate()"

# С сидами пока не разобрал. Буду в ручную накатывать по мере необходимости.
# docker compose run --rm --entrypoint /messenger/bin/messenger web \ eval "Messenger.Release.seed()"
# echo "=== Running Database Seeds ==="
# /messenger/bin/messenger eval "Messenger.Release.seed()"

echo "=== Starting Phoenix Server ==="
exec /messenger/bin/messenger start