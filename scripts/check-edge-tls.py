"""Real loopback Caddy TLS/forwarding test using a controlled protocol fixture.

This does not claim production application/container/public certificate acceptance.
No CA is installed into the host trust store; only this client's explicit trust
context accepts the temporary local root.
"""

import argparse
import json
import socket
import ssl
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def available_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def verify(executable: Path):
    received = []

    class Upstream(BaseHTTPRequestHandler):
        def do_GET(self):
            received.append(dict(self.headers))
            body = json.dumps({"success": True, "data": {"status": "protocol-fixture"}}).encode()
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_args):
            pass

    upstream = ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
    thread = threading.Thread(target=upstream.serve_forever)
    thread.start()
    http_port, tls_port, health_port = (
        available_port(),
        available_port(),
        available_port(),
    )
    with tempfile.TemporaryDirectory(prefix="maizedoctor-edge-") as temporary:
        folder = Path(temporary)
        source = (ROOT / "infrastructure/runtime/Caddyfile").read_text()
        source = source.replace(
            ("admin off"),
            ('admin off\n    storage file_system {\n        root "')
            + folder.as_posix()
            + ('/storage"\n    }'),
        )
        source = source.replace("http://{$API_HOST}", f"http://api.localhost:{http_port}")
        source = source.replace("http://127.0.0.1:9080", f"http://127.0.0.1:{health_port}")
        source = source.replace(
            ("{$API_HOST} {"),
            f"https://api.localhost:{tls_port} {{\n    bind 127.0.0.1",
        )
        source = source.replace(
            ("http://api.localhost:") + str(http_port) + (" {"),
            ("http://api.localhost:") + str(http_port) + (" {\n    bind 127.0.0.1"),
        )
        source = source.replace("{$PUBLIC_HTTPS_ORIGIN}", f"https://api.localhost:{tls_port}")
        source = source.replace("import /etc/caddy/tls.caddy", "tls internal")
        source = source.replace("api:3000", f"127.0.0.1:{upstream.server_port}")
        config = folder / "Caddyfile"
        config.write_text(source)
        with (folder / "private.log").open("wb") as log:
            process = subprocess.Popen(
                [
                    str(executable),
                    ("run"),
                    ("--config"),
                    str(config),
                    ("--adapter"),
                    ("caddyfile"),
                ],
                stdout=log,
                stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess, ("CREATE_NO_WINDOW"), 0),
            )
            try:
                certificate = folder / "storage/pki/authorities/local/root.crt"
                deadline = time.monotonic() + 20
                while (
                    not certificate.exists()
                    and process.poll() is None
                    and time.monotonic() < deadline
                ):
                    time.sleep(0.1)
                if not certificate.exists():
                    raise RuntimeError("Local CA startup failed; no global trust was changed")
                context = ssl.create_default_context(cafile=str(certificate))

                def request(path, extra=""):
                    with (
                        socket.create_connection(("127.0.0.1", tls_port), timeout=5) as raw,
                        context.wrap_socket(raw, server_hostname="api.localhost") as secured,
                    ):
                        secured.sendall(
                            (
                                ("GET ")
                                + path
                                + (" HTTP/1.1\r\nHost: api.localhost\r\nConnection: close\r\n")
                                + extra
                                + ("\r\n")
                            ).encode()
                        )
                        output = b""
                        while part := secured.recv(8192):
                            output += part
                            if len(output) > 65536:
                                raise ValueError("Unexpected edge output size")
                        return output.decode()

                # Health listener may bind before automatic local cert issuance.
                while True:
                    try:
                        output = request(
                            ("/api/v1/health"),
                            ("X-Forwarded-For: 8.8.8.8\r\nForwarded: for=8.8.8.8\r\n"),
                        )
                        break
                    except (OSError, ssl.SSLError):
                        if time.monotonic() >= deadline:
                            raise
                        time.sleep(0.1)
                assert output.startswith("HTTP/1.1 200")
                assert "Strict-Transport-Security:" in output
                assert received[-1].get("X-Forwarded-For") == "127.0.0.1"
                assert received[-1].get("X-Forwarded-Proto") == "https"
                assert not received[-1].get("Forwarded")
                for path in ("/internal/metrics", "/docs", "/openapi.json", "/redoc"):
                    assert request(path).startswith("HTTP/1.1 404")
                with socket.create_connection(("127.0.0.1", http_port), timeout=5) as raw:
                    raw.sendall(
                        b"GET /api/v1/health HTTP/1.1\r\n"
                        b"Host: api.localhost\r\nConnection: close\r\n\r\n"
                    )
                    redirect = raw.recv(8192).decode()
                assert redirect.startswith("HTTP/1.1 308")
                assert f"Location: https://api.localhost:{tls_port}/api/v1/health" in redirect
                return {
                    ("status"): ("PASS"),
                    ("verifiedLocalTLS"): True,
                    ("forwardingSpoofRejected"): True,
                    ("privatePathsBlocked"): 4,
                    ("httpsRedirect"): True,
                    ("publicTLSClaim"): False,
                    ("upstream"): ("controlled protocol fixture"),
                }
            finally:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
                upstream.shutdown()
                thread.join(3)
                upstream.server_close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--caddy", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.caddy.resolve())))
