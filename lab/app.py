# ЗАГЛУШКА. Автор заданий заменит её на WEB-01 (с намеренной уязвимостью).
# Контракт с DevOps:
#   - слушать 5000, отдавать GET /health -> 200
#   - приложение живёт под префиксом /lab/, поэтому ссылки и редиректы
#     внутри должны быть ОТНОСИТЕЛЬНЫМИ ("health", а не "/health")
#   - ничего не писать на диск (корневая ФС read-only; можно писать в /tmp)
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            body, ctype = b"ok", "text/plain"
        else:
            body = "<h1>Lab stub</h1><p><a href='health'>health</a></p>".encode()
            ctype = "text/html; charset=utf-8"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 5000), Handler).serve_forever()
