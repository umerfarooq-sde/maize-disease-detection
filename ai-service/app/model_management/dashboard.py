"""Safe projections of pinned evaluation evidence and bounded process-local counters."""

import math
from datetime import UTC, datetime
from threading import Lock
from time import perf_counter
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

LABELS = ("Common_Rust", "Gray_Leaf_Spot", "Healthy", "Northern_Corn_Leaf_Blight")


class Evidence(BaseModel):
    model_config = ConfigDict(extra="ignore", strict=True, allow_inf_nan=False)


class ClassMetrics(Evidence):
    label: str
    support: int = Field(ge=0)
    precision: float | None = Field(ge=0, le=1)
    recall: float | None = Field(ge=0, le=1)
    f1: float | None = Field(ge=0, le=1)
    specificity: float | None = Field(ge=0, le=1)


class Evaluation(Evidence):
    class_names: list[str]
    sample_count: int = Field(gt=0)
    accuracy: float = Field(ge=0, le=1)
    macro_precision: float = Field(ge=0, le=1)
    macro_recall: float = Field(ge=0, le=1)
    macro_f1: float = Field(ge=0, le=1)
    per_class: list[ClassMetrics]
    confusion_matrix: list[list[int]]

    @model_validator(mode="after")
    def consistent(self) -> "Evaluation":
        matrix = self.confusion_matrix
        if (
            tuple(self.class_names) != LABELS
            or tuple(item.label for item in self.per_class) != LABELS
            or len(matrix) != 4
            or any(len(row) != 4 or any(value < 0 for value in row) for row in matrix)
            or sum(map(sum, matrix)) != self.sample_count
            or any(sum(matrix[i]) != item.support for i, item in enumerate(self.per_class))
            or not math.isclose(
                sum(matrix[i][i] for i in range(4)) / self.sample_count, self.accuracy
            )
        ):
            raise ValueError("Evaluation labels, support and confusion counts must reconcile")
        return self


class DevelopmentSnapshot(Evidence):
    architecture: str = Field(min_length=1, max_length=120)
    datasetVersion: str
    indexFingerprint: str = Field(pattern=r"^[a-f0-9]{64}$")
    experimentId: str
    # This artifact has no recorded training timestamp. Never substitute registration time.
    trainedAt: None = None
    evaluation: Evaluation


def development_snapshot(encoded_metadata: bytes) -> DevelopmentSnapshot:
    """Called only after the existing metadata SHA verification at model startup."""
    import json

    metadata = json.loads(encoded_metadata)
    return DevelopmentSnapshot(
        architecture=metadata["architecture"],
        datasetVersion=metadata["dataset"]["version"],
        indexFingerprint=metadata["dataset"]["manifest_fingerprint"],
        experimentId=metadata["training_experiment_id"],
        evaluation=Evaluation.model_validate(
            metadata["metrics"]["final_test"]["raw_classification"]
        ),
    )


class RuntimeSnapshot(BaseModel):
    scope: Literal["PROCESS_SINCE_START"] = "PROCESS_SINCE_START"
    since: str
    requests: int
    inFlight: int
    successes: int
    failures: int
    lowConfidence: int
    lowConfidenceRate: float | None
    meanLatencyMs: float | None
    predictionDistribution: dict[str, int]


class RuntimeStatistics:
    """Fixed-size, thread-safe; no image, identity or unbounded request samples."""

    def __init__(self) -> None:
        self._lock = Lock()
        self._since = datetime.now(UTC).isoformat()
        self._requests = self._in_flight = self._successes = self._failures = self._low = 0
        self._duration = 0.0
        self._distribution = dict.fromkeys(LABELS, 0)

    def begin(self) -> float:
        with self._lock:
            self._requests += 1
            self._in_flight += 1
        return perf_counter()

    def finish(self, started: float, label: str | None, low_confidence: bool = False) -> None:
        with self._lock:
            self._in_flight -= 1
            self._duration += max(0, (perf_counter() - started) * 1000)
            if label in self._distribution:
                self._successes += 1
                self._distribution[label] += 1
                self._low += int(low_confidence)
            else:
                self._failures += 1

    def snapshot(self) -> RuntimeSnapshot:
        with self._lock:
            completed = self._successes + self._failures
            return RuntimeSnapshot(
                since=self._since,
                requests=self._requests,
                inFlight=self._in_flight,
                successes=self._successes,
                failures=self._failures,
                lowConfidence=self._low,
                lowConfidenceRate=self._low / self._successes if self._successes else None,
                meanLatencyMs=self._duration / completed if completed else None,
                predictionDistribution=dict(self._distribution),
            )
