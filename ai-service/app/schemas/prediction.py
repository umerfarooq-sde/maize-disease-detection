"""Prediction data is a model suggestion with explicit uncertainty semantics."""

from typing import Literal, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.common import ResponseMetadata

PredictionStatus = Literal["CONFIDENT", "LOW_CONFIDENCE"]
UncertaintyReason = Literal["BELOW_VALIDATION_THRESHOLD", "THRESHOLD_UNCONFIGURED"]


class ClassProbability(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

    class_name: str = Field(serialization_alias="className")
    probability: float = Field(ge=0, le=1)


class PredictionData(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

    predicted_class: str = Field(serialization_alias="predictedClass")
    confidence: float = Field(ge=0, le=1)
    top_probabilities: list[ClassProbability] = Field(
        min_length=1, max_length=4, serialization_alias="topProbabilities"
    )
    model_version: str = Field(serialization_alias="modelVersion")
    preprocessing_version: str = Field(serialization_alias="preprocessingVersion")
    inference_duration_ms: float = Field(ge=0, serialization_alias="inferenceDurationMs")
    prediction_status: PredictionStatus = Field(serialization_alias="predictionStatus")
    uncertainty_reason: UncertaintyReason | None = Field(serialization_alias="uncertaintyReason")
    confidence_threshold: float | None = Field(
        ge=0, le=1, serialization_alias="confidenceThreshold"
    )

    @model_validator(mode="after")
    def coherent_uncertainty(self) -> Self:
        if self.confidence_threshold is None:
            if (
                self.prediction_status != "LOW_CONFIDENCE"
                or self.uncertainty_reason != "THRESHOLD_UNCONFIGURED"
            ):
                raise ValueError("An unconfigured threshold cannot establish confidence")
        elif self.confidence < self.confidence_threshold:
            if (
                self.prediction_status != "LOW_CONFIDENCE"
                or self.uncertainty_reason != "BELOW_VALIDATION_THRESHOLD"
            ):
                raise ValueError("Below-threshold predictions require uncertainty")
        elif self.prediction_status != "CONFIDENT" or self.uncertainty_reason is not None:
            raise ValueError("Threshold-qualified predictions require coherent status")
        return self


class PredictionResponse(BaseModel):
    success: Literal[True] = True
    data: PredictionData
    meta: ResponseMetadata
