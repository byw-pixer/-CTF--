#!/usr/bin/env bash
# Проверки приёмки для инфраструктуры. Запускать при поднятом стеке:
#   docker compose up -d --build && ./scripts/check.sh
cd "$(dirname "$0")/.."

FAILED=0
ok()   { echo "[ OK ] $1"; }
fail() { echo "[FAIL] $1"; FAILED=1; }

LAB_ID=$(docker compose ps -q lab-web)
APP_ID=$(docker compose ps -q app)
lab_inspect() { docker inspect "$LAB_ID" --format "$1"; }

# доступность
curl -fsSL -o /dev/null http://localhost:8080/    && ok "платформа открывается на localhost:8080" || fail "платформа не открывается на :8080"
curl -fsSL -o /dev/null http://localhost:8080/lab/ && ok "лаборатория открывается через /lab/"    || fail "лаборатория не открывается через /lab/"
[[ "$(docker compose port nginx 80)" == "127.0.0.1:8080" ]] && ok "nginx слушает только 127.0.0.1:8080" || fail "nginx опубликован не только на 127.0.0.1"
[[ "$(docker inspect "$APP_ID" --format '{{json .HostConfig.PortBindings}}')" == "{}" ]] && ok "платформа не опубликована наружу напрямую" || fail "порт платформы опубликован наружу"

# изоляция лаборатории
if docker compose exec -T lab-web python -c "import socket; socket.create_connection(('app', 8000), 2)" >/dev/null 2>&1; then
  fail "лаборатория МОЖЕТ достучаться до платформы"; else ok "лаборатория не видит платформу"; fi
if docker compose exec -T lab-web python -c "import socket; socket.create_connection(('1.1.1.1', 53), 2)" >/dev/null 2>&1; then
  fail "у лаборатории есть выход в интернет"; else ok "у лаборатории нет выхода в интернет"; fi
lab_inspect '{{json .Mounts}}' | grep -q docker.sock && fail "в лабораторию смонтирован docker.sock" || ok "docker.sock в лабораторию не смонтирован"
[[ "$(lab_inspect '{{.HostConfig.Privileged}}')" == "false" ]] && ok "лаборатория не privileged" || fail "лаборатория privileged"
[[ "$(lab_inspect '{{.HostConfig.ReadonlyRootfs}}')" == "true" ]] && ok "корневая ФС лаборатории read-only" || fail "корневая ФС лаборатории доступна на запись"
[[ "$(lab_inspect '{{.HostConfig.NetworkMode}}')" != "host" ]] && ok "лаборатория без host network" || fail "лаборатория в host network"
[[ "$(docker compose exec -T lab-web id -u | tr -d '\r')" != "0" ]] && ok "лаборатория работает не от root" || fail "лаборатория работает от root"

# отказоустойчивость: лаборатория остановлена, платформа жива
docker compose stop lab-web >/dev/null
code_lab=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/lab/)
code_root=$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/)
docker compose start lab-web >/dev/null
if [[ "$code_lab" == "503" && "$code_root" == "200" ]]; then
  ok "при остановленной лаборатории: /lab/ -> 503 с понятной страницей, платформа -> 200"
else
  fail "остановленная лаборатория ломает платформу (lab=$code_lab, /=$code_root)"
fi

echo; echo "Потребление ресурсов:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

exit $FAILED
