from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.common import ResponseMetadata


class ModelHealthData(BaseModel):
    status: Literal["ready", "not_loaded"]
    model_version: str | None = Field(serialization_alias="modelVersion")
    preprocessing_version: str | None = Field(serialization_alias="preprocessingVersion")
    class_mapping: dict[str, int] = Field(serialization_alias="classMapping")
    confidence_threshold: float | None = Field(serialization_alias="confidenceThreshold")
    confidence_policy: Literal["UNCONFIGURED", "VALIDATION_BASED"] = Field(
        serialization_alias="confidencePolicy"
    )
    calibration: Literal["none", "temperature"]
    use_scope: Literal["non-commercial academic/FYP research"] = Field(
        default="non-commercial academic/FYP research", serialization_alias="useScope"
    )


class ModelHealthResponse(BaseModel):
    success: Literal[True] = True
    data: ModelHealthData
    meta: ResponseMetadata
