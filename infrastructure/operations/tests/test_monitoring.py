import pytest

from preparation import redis_configuration
from verify_monitoring import host


def test_shared_redis_acl_is_namespaced_and_bounded():
    configuration = redis_configuration("md-component", "a" * 43)
    assert "user default off" in configuration
    assert "~{md-component}:*" in configuration
    assert "maxmemory 128mb" in configuration
    assert "noeviction" in configuration
    assert "+@all" not in configuration


@pytest.mark.parametrize(
    "namespace,password", [("bad\nuser evil", "a" * 43), ("valid", "a\n+@all")]
)
def test_redis_configuration_rejects_acl_injection(namespace, password):
    with pytest.raises(ValueError):
        redis_configuration(namespace, password)


def test_monitoring_host_probe_cannot_touch_an_operator_host(monkeypatch):
    monkeypatch.delenv("GITHUB_ACTIONS", raising=False)
    with pytest.raises(ValueError, match="disposable Linux"):
        host()
