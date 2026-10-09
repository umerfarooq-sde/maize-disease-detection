from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import ResponseMetadata


class HealthQuery(BaseModel):
    """Health accepts no query parameters; reject unexpected input explicitly."""

    model_config = ConfigDict(extra="forbid")


class Capabilities(BaseModel):
    preprocessing: Literal["library_available"] = "library_available"
    inference: Literal["ready", "unavailable"] = "unavailable"
    rag: Literal["not_implemented"] = "not_implemented"
    generation: Literal["not_implemented"] = "not_implemented"


class ModelHealth(BaseModel):
    """Basic safe readiness; detailed model policy is protected separately."""

    status: Literal["ready", "not_loaded"] = "not_loaded"
    version: str | None = None


class HealthData(BaseModel):
    service: str
    version: str
    status: Literal["ok", "starting"]
    uptime_seconds: float = Field(ge=0, serialization_alias="uptimeSeconds")
    capabilities: Capabilities = Field(default_factory=Capabilities)
    model: ModelHealth = Field(default_factory=ModelHealth)


class HealthResponse(BaseModel):
    success: Literal[True] = True
    data: HealthData
    meta: ResponseMetadata
