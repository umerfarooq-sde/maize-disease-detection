from pydantic import BaseModel, ConfigDict, Field


class ResponseMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: str = Field(serialization_alias="requestId")
