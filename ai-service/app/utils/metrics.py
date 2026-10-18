"""Bounded operational Prometheus labels, never content/identities/DSNs."""

import threading
from collections import defaultdict

_lock = threading.Lock()
_counts: dict[tuple[str, str], int] = defaultdict(int)
_seconds: dict[tuple[str, str], float] = defaultdict(float)
_ALLOWED = {
    "dns",
    "connect",
    "query",
    "commit",
    "retrieval",
    "inference",
    "generation",
    "gemini",
    "embedding",
    "explanation",
    "telemetry",
}


def observe(stage: str, outcome: str, seconds: float = 0) -> None:
    if stage not in _ALLOWED or outcome not in {"success", "failure", "timeout", "dropped"}:
        return
    with _lock:
        _counts[stage, outcome] += 1
        _seconds[stage, outcome] += max(0, seconds)


def render() -> str:
    with _lock:
        rows = [(key, value, _seconds[key]) for key, value in _counts.items()]
    result = [
        "# HELP maizedoctor_ai_operations_total Observed operations; not lossless accounting.",
        "# TYPE maizedoctor_ai_operations_total counter",
        "# HELP maizedoctor_ai_operation_seconds_total Cumulative observed duration.",
        "# TYPE maizedoctor_ai_operation_seconds_total counter",
    ]
    for (stage, outcome), count, seconds in sorted(rows):
        labels = f'stage="{stage}",outcome="{outcome}"'
        result.extend(
            [
                f"maizedoctor_ai_operations_total{{{labels}}} {count}",
                f"maizedoctor_ai_operation_seconds_total{{{labels}}} {seconds}",
            ]
        )
    return "\n".join(result) + "\n"
