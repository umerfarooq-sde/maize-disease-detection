"""Disposable local PostgreSQL CA. Production certificates belong to its operator."""

import os
import subprocess
from pathlib import Path

directory = Path("/certificates")
directory.mkdir(exist_ok=True)
if not (directory / "server.key").exists():

    def openssl(*args):
        subprocess.run(
            ["openssl", *args],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    openssl(
        "req",
        "-x509",
        "-newkey",
        "rsa:3072",
        "-nodes",
        "-days",
        "30",
        "-subj",
        "/CN=MAIZEDOCTOR disposable PostgreSQL CA",
        "-keyout",
        str(directory / "root.key"),
        "-out",
        str(directory / "root.crt"),
    )
    openssl(
        "req",
        "-newkey",
        "rsa:3072",
        "-nodes",
        "-subj",
        "/CN=postgres",
        "-keyout",
        str(directory / "server.key"),
        "-out",
        str(directory / "server.csr"),
    )
    (directory / "extensions").write_text(
        "subjectAltName=DNS:postgres\nextendedKeyUsage=serverAuth\n", encoding="ascii"
    )
    openssl(
        "x509",
        "-req",
        "-in",
        str(directory / "server.csr"),
        "-CA",
        str(directory / "root.crt"),
        "-CAkey",
        str(directory / "root.key"),
        "-CAcreateserial",
        "-days",
        "30",
        "-extfile",
        str(directory / "extensions"),
        "-out",
        str(directory / "server.crt"),
    )
    os.chmod(directory / "server.key", 0o600)
    os.chown(directory / "server.key", 999, 999)
    # The CA signing key is not needed by runtime services; remove this newly
    # generated disposable key after issuing the server certificate.
    (directory / "root.key").unlink()
print("Local PostgreSQL certificate material exists; runtime verifies its CA and hostname.")
