"""Optional pinned validation-only policy; no numerical default or TEST selection."""

from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, ValidationError

from app.model_management.artifacts import LoadedModel, ModelStartupError


class ConfidencePolicy(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, frozen=True, allow_inf_nan=False)

    schema_version: Literal[1]
    decision_status: Literal["approved_for_research"]
    selected_using: Literal["validation"]
    model_version: str
    checkpoint_sha256: str = Field(pattern=r"^[a-f0-9]{64}$")
    validation_predictions_sha256: str = Field(pattern=r"^[a-f0-9]{64}$")
    threshold: float = Field(gt=0, lt=1)
    rationale: str = Field(min_length=20, max_length=2000)


def load_confidence_policy(path: Path, expected_sha256: str, model: LoadedModel) -> float:
    """An operator must document/approve a validation decision before configuring it."""
    try:
        with path.open("rb") as handle:
            content = handle.read(16 * 1024 + 1)
        if len(content) > 16 * 1024 or hashlib.sha256(content).hexdigest() != expected_sha256:
            raise ValueError("Policy integrity mismatch")
        policy = ConfidencePolicy.model_validate_json(content)
        if (
            policy.model_version != model.model_version
            or policy.checkpoint_sha256 != model.checkpoint_sha256
            or policy.validation_predictions_sha256 != model.validation_predictions_sha256
        ):
            raise ValueError("Policy does not belong to this validation-selected model")
        return policy.threshold
    except (OSError, ValueError, ValidationError):
        raise ModelStartupError("CONFIDENCE_POLICY_INVALID") from None
