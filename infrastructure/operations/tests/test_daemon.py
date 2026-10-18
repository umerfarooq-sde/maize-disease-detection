import json
import logging
import threading
import urllib.error
import urllib.request
from http.server import HTTPServer

import pytest
from daemon import State, handler, sanitize_alerts


def test_alert_journal_drops_private_annotations_and_unbounded_labels():
    records = sanitize_alerts(
        json.dumps(
            {
                "alerts": [
                    {
                        "status": "firing",
                        "labels": {
                            "alertname": "DatabaseFailures",
                            "job": "node",
                            "private": "secret",
                        },
                        "annotations": {"prompt": "private user content"},
                    }
                ]
            }
        ).encode()
    )
    assert records[0]["labels"] == {"alertname": "DatabaseFailures", "job": "node"}
    assert "private" not in json.dumps(records)
    for body in (b"x" * 65537, b"{", b'{"alerts":[{}]}'):
        with pytest.raises(ValueError):
            sanitize_alerts(body)


def test_private_alert_delivery_and_metrics_are_real_http(caplog):
    state = State("alerts", "a" * 43)
    server = HTTPServer(("127.0.0.1", 0), handler(state, logging.getLogger("test-alerts")))
    thread = threading.Thread(target=server.serve_forever)
    thread.start()
    origin = f"http://127.0.0.1:{server.server_port}"
    try:
        with pytest.raises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(origin + "/internal/metrics")
        assert error.value.code == 404
        headers = {"Authorization": "Bearer " + "a" * 43}
        request = urllib.request.Request(
            origin + "/events",
            data=json.dumps(
                {
                    "alerts": [
                        {
                            "status": "firing",
                            "labels": {"alertname": "DatabaseFailures"},
                        }
                    ]
                }
            ).encode(),
            headers=headers,
        )
        assert urllib.request.urlopen(request).status == 202
        request = urllib.request.Request(origin + "/internal/metrics", headers=headers)
        assert (
            "maizedoctor_alerts_received_total 1" in urllib.request.urlopen(request).read().decode()
        )
        assert "operational_alert" in caplog.text
        assert state.alerts == 1
    finally:
        server.shutdown()
        thread.join(2)
        server.server_close()


def test_storage_failure_is_observable_unknown_not_fabricated_zero(tmp_path, monkeypatch):
    import daemon

    state = State("backup", "synthetic")
    state.disk_directory = tmp_path
    assert "maizedoctor_operational_storage_observation_available 1" in state.metrics()

    def unavailable(_directory):
        raise OSError("private disk detail")

    monkeypatch.setattr(daemon.shutil, "disk_usage", unavailable)
    metrics = state.metrics()
    assert "maizedoctor_operational_storage_observation_available 0" in metrics
    assert "maizedoctor_operational_storage_bytes" not in metrics
    assert "private" not in metrics
