"""Production total DNS/address budget with a killable, credential-free resolver."""

import json
import os
import subprocess
import sys
import threading
from time import monotonic
from typing import cast

import psycopg
from psycopg.conninfo import conninfo_to_dict
from psycopg.rows import dict_row

from app.utils.metrics import observe

DNS_PROGRAM = """import json,socket,sys
host,port=json.load(sys.stdin)
rows=socket.getaddrinfo(host,port,type=socket.SOCK_STREAM,proto=socket.IPPROTO_TCP)
print(json.dumps(list(dict.fromkeys(str(row[4][0]) for row in rows))[:32]))
"""


def resolve_addresses(host: str, port: str, timeout: float) -> list[str]:
    allowed = {"PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP", "HOME", "LANG", "LC_ALL"}
    environment = {key: value for key, value in os.environ.items() if key.upper() in allowed}
    try:
        result = subprocess.run(
            # Windows venv launchers can spawn a second interpreter. Use the
            # base interpreter for this stdlib-only task so timeout kills the
            # actual resolver process rather than merely its launcher.
            [
                cast(str, getattr(sys, "_base_executable", sys.executable)),
                "-I",
                "-S",
                "-c",
                DNS_PROGRAM,
            ],
            input=json.dumps([host, port]),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            env=environment,
            timeout=timeout,
            check=True,
            creationflags=cast(int, getattr(subprocess, "CREATE_NO_WINDOW", 0)),
        )
        if len(result.stdout) > 4096:
            raise ValueError()
        addresses = json.loads(result.stdout)
        if (
            not isinstance(addresses, list)
            or not 1 <= len(addresses) <= 32
            or not all(isinstance(address, str) and len(address) <= 64 for address in addresses)
        ):
            raise ValueError()
        return cast(list[str], addresses)
    except (subprocess.SubprocessError, OSError, ValueError):
        raise psycopg.OperationalError("database DNS deadline or resolution failure") from None


class DatabaseConnector:
    def __init__(self, budget: float = 8) -> None:
        self.budget = budget
        self.slots = threading.BoundedSemaphore(2)
        self.closed = False

    def connect(self, url: str) -> psycopg.Connection[dict[str, object]]:
        if self.closed or not self.slots.acquire(blocking=False):
            raise psycopg.OperationalError("database resolver unavailable")
        started = monotonic()
        try:
            parameters = conninfo_to_dict(url)
            host, port = str(parameters.get("host", "")), str(parameters.get("port", "5432"))
            if not host or "," in host or parameters.get("hostaddr"):
                raise psycopg.OperationalError("unsupported database endpoint")
            addresses = resolve_addresses(host, port, min(1.5, self.budget))
            observe("dns", "success", monotonic() - started)
        except psycopg.Error:
            observe("dns", "failure", monotonic() - started)
            raise
        finally:
            self.slots.release()
        for address in addresses:
            remaining = self.budget - (monotonic() - started)
            if self.closed or remaining < 2:
                break
            attempt = monotonic()
            try:
                result = psycopg.connect(
                    url,
                    hostaddr=address,
                    connect_timeout=min(5, int(remaining)),
                    row_factory=dict_row,
                )
                observe("connect", "success", monotonic() - attempt)
                return cast(psycopg.Connection[dict[str, object]], result)
            except psycopg.OperationalError as error:
                observe("connect", "failure", monotonic() - attempt)
                message = str(error).lower()
                if "certificate" in message or "ssl" in message or "tls" in message:
                    raise psycopg.OperationalError("database TLS verification failed") from None
                if "authentication" in message or "password" in message:
                    raise psycopg.OperationalError("database authentication rejected") from None
        raise psycopg.OperationalError("database connection deadline exceeded")

    def close(self) -> None:
        self.closed = True
