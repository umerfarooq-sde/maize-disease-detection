FROM postgres:18.4-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-venv ca-certificates openssl && rm -rf /var/lib/apt/lists/*
WORKDIR /operations
COPY infrastructure/operations/requirements.lock ./
RUN python3 -m venv /opt/operations && /opt/operations/bin/pip install --require-hashes --no-cache-dir -r requirements.lock && useradd --uid 10002 --create-home operations
RUN mkdir /backups /inbox && chown operations:operations /backups /inbox
COPY infrastructure/operations/ ./
ENV PATH=/opt/operations/bin:$PATH PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
USER operations
ENTRYPOINT ["python", "manage.py"]
