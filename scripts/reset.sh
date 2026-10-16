#!/usr/bin/env bash
# Полный сброс тестовых данных: пользователи, попытки, решения, рейтинг.
set -euo pipefail
cd "$(dirname "$0")/.."

read -r -p "Удалить ВСЕ данные платформы? [y/N] " answer
[[ "$answer" == "y" ]] || { echo "Отмена"; exit 1; }

docker compose down -v          # -v удаляет volume с SQLite
docker compose up -d --build
echo "Готово: база пересоздана, админ создаётся из .env"
