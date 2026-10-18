"""Bounded metadata-only provider telemetry, owned and joined by service lifespan.

Best effort: queue-full, storage failure and abrupt process loss can lose events.
No raw content, personal identifiers, provider messages or credentials are queued.
"""

import logging
import queue
import threading
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from contextvars import ContextVar
from datetime import UTC, datetime
from functools import wraps
from time import perf_counter
from typing import ParamSpec, TypeVar
from uuid import uuid4

from app.utils.errors import AppError
from app.utils.metrics import observe

CURRENT: ContextVar["OperationsRecorder | None"] = ContextVar("operational_recorder", default=None)


class OperationsRecorder:
    def __init__(self, sink: Callable[[dict[str, object]], None]) -> None:
        self.sink = sink
        self.events: queue.Queue[dict[str, object]] = queue.Queue(maxsize=128)
        self.stopping = threading.Event()
        self.dropped = 0
        self.worker = threading.Thread(
            target=self._write, name="ai-operational-events", daemon=True
        )
        self.worker.start()

    def _write(self) -> None:
        while not self.stopping.is_set() or not self.events.empty():
            try:
                event = self.events.get(timeout=0.1)
            except queue.Empty:
                continue
            try:
                self.sink(event)
            except Exception:
                self.dropped += 1
                observe("telemetry", "dropped")
                logging.getLogger("maizedoctor.ai").warning("ai_telemetry_storage_failed")
            finally:
                self.events.task_done()

    def close(self) -> None:
        self.stopping.set()
        if not self.wait_stopped(3):
            logging.getLogger("maizedoctor.ai").warning("ai_telemetry_shutdown_incomplete")

    def wait_stopped(self, timeout: float) -> bool:
        """Owned fixture/operator wait; service close keeps its three-second boundary."""
        self.worker.join(timeout=timeout)
        return not self.worker.is_alive()

    def record(
        self,
        operation: str,
        started: float,
        error: BaseException | None,
        scope: str = "PROVIDER",
        abstained: bool = False,
    ) -> None:
        code = str(error.code) if isinstance(error, AppError) else ""
        category = (
            None
            if error is None
            else (
                "TIMEOUT"
                if "TIMEOUT" in code
                else "INVALID_RESPONSE"
                if "INVALID" in code
                else "UNAVAILABLE"
                if "UNAVAILABLE" in code
                else "INTERNAL"
            )
        )
        event: dict[str, object] = {
            "id": str(uuid4()),
            "scope": scope,
            "operation": operation,
            "outcome": "FAILED" if error is not None else "ABSTAINED" if abstained else "SUCCESS",
            "category": category,
            "durationMs": min(86400000, round((perf_counter() - started) * 1000)),
            "occurredAt": datetime.now(UTC),
        }
        try:
            observe(operation.lower(), "failure" if error else "success", perf_counter() - started)
            self.events.put_nowait(event)
        except queue.Full:
            self.dropped += 1
            observe("telemetry", "dropped")
            logging.getLogger("maizedoctor.ai").warning("ai_telemetry_capacity_exceeded")


@contextmanager
def provider_operation(operation: str) -> Iterator[None]:
    started = perf_counter()
    failure: BaseException | None = None
    try:
        yield
    except BaseException as error:
        failure = error
        raise
    finally:
        recorder = CURRENT.get()
        if recorder is not None:
            recorder.record(operation, started, failure)


P = ParamSpec("P")
T = TypeVar("T")


def service_operation(operation: str) -> Callable[[Callable[P, T]], Callable[P, T]]:
    def decorate(function: Callable[P, T]) -> Callable[P, T]:
        @wraps(function)
        def measured(*args: P.args, **kwargs: P.kwargs) -> T:
            started = perf_counter()
            failure: BaseException | None = None
            abstained = False
            try:
                result = function(*args, **kwargs)
                abstained = getattr(result, "status", None) in {
                    "OUT_OF_SCOPE",
                    "INSUFFICIENT_INFORMATION",
                    "CONFLICTING_EVIDENCE",
                }
                return result
            except BaseException as error:
                failure = error
                raise
            finally:
                recorder = CURRENT.get()
                if recorder is not None:
                    recorder.record(operation, started, failure, "AI_SERVICE", abstained)

        return measured

    return decorate
