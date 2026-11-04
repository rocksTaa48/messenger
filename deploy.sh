#!/usr/bin/env bash
#
# deploy.sh — pull из git + пересборка и рестарт контейнеров
# Использование: ./deploy.sh [branch]
#   branch по умолчанию — текущая ветка
#
set -euo pipefail

# ---------------- Настройки ----------------
PROJECT_DIR="/home/rockstaa/messenger"
BRANCH="${1:-$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)}"
LOG_FILE="$PROJECT_DIR/deploy.log"
COMPOSE="docker compose"

# ---------------- Цвета ----------------
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] WARN${NC} $*" | tee -a "$LOG_FILE"; }
err()  { echo -e "${RED}[$(date +%H:%M:%S)] ERROR${NC} $*" | tee -a "$LOG_FILE" >&2; }

# ---------------- Проверки перед стартом ----------------
cd "$PROJECT_DIR"

if [[ ! -f .env ]]; then
  err ".env не найден в $PROJECT_DIR. Прерываю."
  exit 1
fi

if [[ ! -f docker-compose.yml ]]; then
  err "docker-compose.yml не найден. Прерываю."
  exit 1
fi

if ! command -v docker &>/dev/null; then
  err "docker не установлен. Прерываю."
  exit 1
fi

# Проверим, что APP_HOST задан (иначе check_origin снова сломается)
if ! grep -q '^APP_HOST=' .env; then
  warn "APP_HOST не задан в .env — WebSocket/LiveView могут не работать!"
fi

log "=== Деплой начат. Ветка: $BRANCH ==="

# ---------------- Git ----------------
log "Сохраняю текущий коммит для возможного отката..."
PREV_COMMIT=$(git rev-parse HEAD)
log "Предыдущий коммит: $PREV_COMMIT"

log "Тяну изменения из origin/$BRANCH..."
git fetch origin "$BRANCH"
git pull --ff-only origin "$BRANCH"

NEW_COMMIT=$(git rev-parse HEAD)
if [[ "$PREV_COMMIT" == "$NEW_COMMIT" ]]; then
  warn "Новых коммитов нет — пересборка всё равно продолжится."
fi
log "Новый коммит: $NEW_COMMIT"

# ---------------- Сборка ----------------
log "Собираю образ web..."
if ! $COMPOSE build web; then
  err "Сборка упала. Откатываюсь на $PREV_COMMIT..."
  git reset --hard "$PREV_COMMIT"
  exit 1
fi

# ---------------- Деплой ----------------
log "Перезапускаю web..."
$COMPOSE up -d --no-deps --force-recreate web

# ---------------- Health check ----------------
log "Жду готовности web (до 60 сек)..."
ATTEMPTS=0
until $COMPOSE exec -T web sh -c 'nc -z localhost 4000' 2>/dev/null; do
  ATTEMPTS=$((ATTEMPTS+1))
  if [[ $ATTEMPTS -ge 30 ]]; then
    err "web не поднялся за 60 сек. Смотри логи:"
    $COMPOSE logs --tail=50 web
    exit 1
  fi
  sleep 2
done

# Проверим, что эндпоинт слушает правильный хост
sleep 3
HOST_IN_LOGS=$($COMPOSE logs --tail=100 web 2>&1 | grep -o 'Access MessengerWeb.Endpoint at https\?://[^ ]*' | tail -1 || true)
if [[ -n "$HOST_IN_LOGS" ]]; then
  log "Эндпоинт: $HOST_IN_LOGS"
  if echo "$HOST_IN_LOGS" | grep -q "example.com"; then
    warn "Всё ещё example.com! Проверь config/runtime.exs (должен быть 1 блок MessengerWeb.Endpoint)."
  fi
fi

# ---------------- Проверка Caddy ----------------
log "Перезапускаю caddy (если нужно)..."
$COMPOSE up -d --no-deps caddy

log "Проверяю HTTPS снаружи..."
if curl -sS -o /dev/null -w "%{http_code}" https://62.133.62.80.sslip.io/ | grep -qE '^(200|301|302)$'; then
  log "HTTPS отвечает корректно."
else
  warn "HTTPS вернул не 2xx/3xx — проверь Caddy: $COMPOSE logs caddy"
fi

# ---------------- Уборка ----------------
log "Удаляю висячие образы (dangling)..."
docker image prune -f >/dev/null 2>&1 || true

log "=== Деплой завершён успешно ==="
log "Коммит: $NEW_COMMIT"