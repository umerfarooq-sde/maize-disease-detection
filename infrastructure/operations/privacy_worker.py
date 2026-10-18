"""Policy-gated expiration and durable account-erasure recovery scheduler."""

import argparse
import json
import signal
import threading
from pathlib import Path

from database import connect, secret
from privacy import cleanup, destroy_asset, detach, expire, read_policy


def cycle(url, policy_path, destroy):
    policy, _ = read_policy(policy_path)
    if not policy["erasureEnabled"] and all(
        value is None for value in policy["retention"].values()
    ):
        return {"status": "DISABLED", "deleted": False}
    with connect(url, autocommit=True) as lease:
        if not lease.execute(
            "SELECT pg_try_advisory_lock(hashtextextended('maizedoctor-privacy-v1',0))"
        ).fetchone()[0]:
            return {"status": "LEASE_BUSY"}
        try:
            expiration = expire(url, policy_path, execute=True)
            completed = 0
            if policy["erasureEnabled"]:
                rows = lease.execute(
                    "SELECT id,status FROM privacy_requests WHERE status IN ('APP"
                    "ROVED','ASSET_CLEANUP') ORDER BY updated_at LIMIT 10"
                ).fetchall()
                for request_id, status in rows:
                    try:
                        if status == "APPROVED":
                            detach(url, str(request_id), policy_path)
                        result = cleanup(url, str(request_id), policy_path, destroy)
                        completed += result["status"] == "COMPLETED"
                    except Exception:
                        # Durable request remains pending. Do not leak provider
                        # response content, user identity or asset capabilities.
                        print(json.dumps({"event": "privacy_work_pending"}), flush=True)
            return {
                "status": "PROCESSED",
                "completed": completed,
                "expiration": expiration,
            }
        finally:
            lease.execute("SELECT pg_advisory_unlock(hashtextextended('maizedoctor-privacy-v1',0))")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--secrets", type=Path, required=True)
    parser.add_argument("--interval", type=int, default=300)
    args = parser.parse_args()
    if not 60 <= args.interval <= 86400:
        raise ValueError("Invalid scheduling interval")
    stopping = threading.Event()
    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, lambda *_: stopping.set())
    values = secret(args.secrets)
    while not stopping.is_set():
        try:
            print(
                json.dumps(
                    cycle(
                        values["DATABASE_URL"],
                        args.policy,
                        lambda asset: destroy_asset(asset, values["provider"]),
                    )
                ),
                flush=True,
            )
        except Exception:
            print(json.dumps({"event": "privacy_cycle_failed"}), flush=True)
        stopping.wait(args.interval)


if __name__ == "__main__":
    main()
