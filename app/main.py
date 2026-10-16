# ВРЕМЕННАЯ заглушка платформы: показывает UX-макет (static/index.html),
# чтобы весь стек с Nginx и Docker можно было запустить и проверить до того,
# как будет готов настоящий backend. Backend заменит этот файл своим.
#
# Контракт с DevOps:
#   - слушать 8000, отдавать GET /health -> 200
#   - объект приложения называется `app`
#   - БД брать из переменной DATABASE_URL (в Docker: sqlite:////data/cyberarena.db)
#   - SECRET_KEY, ADMIN_USERNAME, ADMIN_PASSWORD брать из окружения
#   - писать на диск только в /data
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse

BASE_DIR = Path(__file__).parent

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/")
def index():
    return FileResponse(BASE_DIR / "static" / "index.html")
