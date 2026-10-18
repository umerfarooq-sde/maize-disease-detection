import json

import observe_containers


def test_failed_replica_cannot_be_hidden_by_later_healthy_replica(monkeypatch):
    identities = ["a" * 12, "b" * 12]

    def output(arguments):
        if arguments[0] == "ps":
            return "\n".join(identities)
        if arguments[0] == "stats":
            return json.dumps({"CPUPerc": "2.5%", "MemUsage": "10MiB / 1GiB"})
        if arguments[0] == "inspect":
            healthy = arguments[-1] == identities[1]
            return json.dumps(
                {
                    "service": "api",
                    "running": healthy,
                    "restarts": int(not healthy),
                    "health": "healthy" if healthy else "unhealthy",
                }
            )
        raise AssertionError("Unexpected Docker query")

    monkeypatch.setattr(observe_containers, "run", output)
    row = observe_containers.collect("synthetic")["api"]
    assert row["running"] == 0 and row["healthy"] == 0 and row["restarts"] == 1
    assert row["memory_bytes"] == 10 * 1024**2
