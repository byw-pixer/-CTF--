# CyberArena: инфраструктура и запуск

Docker Compose, Nginx, изоляция Web-лаборатории, запуск одной командой.

## Требования

- Linux (проверено на CachyOS / Arch Linux), macOS или Windows с Docker Engine и Docker Compose v2
- 8 ГБ RAM, 4 логических CPU, 10 ГБ свободного диска
- свободный порт 8080
- интернет нужен только для первой сборки образов, дальше проект работает офлайн

## Установка Docker (Arch / CachyOS)

```bash
sudo pacman -S docker docker-compose docker-buildx
sudo systemctl enable --now docker.service
sudo usermod -aG docker $USER      # затем выйти из сессии и зайти снова
docker run hello-world             # проверка
```

Пока группа `docker` не применилась, добавляйте `sudo` перед командами `docker`.

## Быстрый старт

```bash
cp .env.example .env               # отредактировать значения
docker compose up -d --build
```

- платформа: <http://localhost:8080>
- лаборатория WEB-01: <http://localhost:8080/lab/>

Проверка инфраструктуры:

```bash
./scripts/check.sh
```

## Файл `.env`

Хранит секреты, в Git не попадает.

```
SECRET_KEY=<длинная случайная строка>
ADMIN_USERNAME=admin
ADMIN_PASSWORD=<надёжный пароль>
```

Сгенерировать ключ: `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`.

Для fish (конструкция `<<'EOF'` в fish не работает):

```fish
printf 'SECRET_KEY=%s\nADMIN_USERNAME=admin\nADMIN_PASSWORD=ваш-пароль\n' (python3 -c "import secrets; print(secrets.token_urlsafe(32))") > .env
```

Учётная запись администратора задаётся только через `.env`, в репозитории паролей нет.

## Команды

| Действие | Команда |
|---|---|
| Состояние сервисов | `docker compose ps` |
| Логи | `docker compose logs -f` (или `docker compose logs -f app`) |
| Остановить / запустить | `docker compose stop` / `docker compose start` |
| Перезапуск (данные сохраняются) | `docker compose restart` |
| Пересобрать | `docker compose up -d --build` |
| Убрать контейнеры (данные остаются) | `docker compose down` |
| Полный сброс тестовых данных | `./scripts/reset.sh` |
| Резервная копия SQLite | `./scripts/backup.sh` |
| Потребление RAM и CPU | `docker stats --no-stream` |

Восстановление из резервной копии:

```bash
docker compose stop app
docker compose cp backups/<файл>.db app:/data/cyberarena.db
docker compose start app
```

## Архитектура

```
Браузер → Nginx (127.0.0.1:8080) ─┬─ /      → app (FastAPI + SQLite, volume db_data)   [app-net]
                                  └─ /lab/  → lab-web (WEB-01)                         [lab-net, internal]
```

Две Docker-сети:

- **app-net**: Nginx и платформа. Наружу выходит только порт Nginx на `127.0.0.1`.
- **lab-net** (`internal: true`): Nginx и лаборатория, без выхода в интернет.

Контейнер лаборатории не подключён к `app-net`, не видит платформу и SQLite, не получает Docker Socket.
Ограничения: non-root, read-only корневая ФС (запись только в `/tmp`), `cap_drop: ALL`, `no-new-privileges`,
0.5 CPU, 256 МБ RAM, лимит процессов. Если лаборатория остановлена, Nginx показывает страницу с кодом 503,
а платформа и рейтинг работают. База лежит в отдельном volume `db_data` и сохраняется после перезапуска.
В production для недоверенных участников нужна дополнительная изоляция на уровне VM.

## Результаты проверки (16.10.2026, CachyOS, Docker Engine + Compose v2)

`docker compose ps`: nginx, app, lab-web в статусе `healthy`, наружу опубликован только `127.0.0.1:8080->80`.

Результат `./scripts/check.sh`:

| Проверка | Результат |
|---|---|
| Платформа открывается на localhost:8080 | OK |
| Лаборатория открывается через `/lab/` | OK |
| Nginx слушает только 127.0.0.1:8080 | OK |
| Платформа не опубликована наружу напрямую | OK |
| Лаборатория не видит платформу | OK |
| У лаборатории нет выхода в интернет | OK |
| `docker.sock` в лабораторию не смонтирован | OK |
| Лаборатория не privileged | OK |
| Корневая ФС лаборатории read-only | OK |
| Лаборатория без host network | OK |
| Лаборатория работает не от root | OK |
| Лаборатория остановлена: `/lab/` → 503 с понятной страницей, платформа → 200 | OK |

Запись `lab-web could not be resolved` в логах Nginx при этой проверке ожидаема: скрипт нарочно останавливает лабораторию.

### Потребление ресурсов

| Сервис | RAM (использовано / лимит) | CPU |
|---|---|---|
| nginx | 2.2 МиБ / 64 МиБ | 0.00% |
| app | 32.4 МиБ / 512 МиБ | 0.17% |
| lab-web | 11.2 МиБ / 256 МиБ | 41.42%* |

\* замер сразу после перезапуска контейнера, кратковременный всплеск при старте.

## Решение проблем

| Симптом                                                             | Причина и решение                                                                                                        |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `env file ... .env not found`                                       | не создан `.env`: `cp .env.example .env`                                                                                 |
| `failed to connect to the docker API ... no such file or directory` | служба Docker не запущена: `sudo systemctl enable --now docker.service`                                                  |
| `permission denied while trying to connect to the docker API`       | пользователь не в группе `docker` или нет перелогина: `sudo usermod -aG docker $USER`, затем перелогин (временно `sudo`) |
| `Expected a string, but found a redirection`                        | в fish не работает `<<'EOF'`, используйте команду для fish выше                                                          |
| `port is already allocated` на 8080                                 | порт занят: `ss -ltnp \| grep 8080`                                                                                      |
| `/lab/` показывает 503                                              | контейнер остановлен: `docker compose start lab-web`, причина в `docker compose logs lab-web`                            |
| `app` не становится `healthy`                                       | смотрите `docker compose logs app`                                                                                       |
