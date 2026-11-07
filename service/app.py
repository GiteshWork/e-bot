
import json
import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


CONFIG_DIR = Path("/etc/app-config")


def get_config(name, default):
    config_file = CONFIG_DIR / name

    if config_file.is_file():
        value = config_file.read_text().strip()
        if value:
            return value

    return os.getenv(name, default)


class ApplicationHandler(BaseHTTPRequestHandler):

    def do_GET(self):

        if self.path == "/":
            response = {
                "app": get_config("APP_NAME", "enterprisebot-demo"),
                "version": get_config("VERSION", "1.0.0"),
                "pod": socket.gethostname()
            }

            self.send_json(200, response)

        elif self.path == "/healthz":
            self.send_json(200, {"status": "healthy"})

        else:
            self.send_json(404, {"error": "Not Found"})

    def send_json(self, status, data):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8080), ApplicationHandler)
    print("Application starting on port 8080")
    server.serve_forever()

