from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.common import ResponseMetadata

ValidationSource = Literal["body", "query", "path", "header", "cookie", "request"]


class ValidationIssue(BaseModel):
    source: ValidationSource
    code: str


class ErrorDetails(BaseModel):
    code: str
    message: str
    issues: list[ValidationIssue] = Field(default_factory=list)


class ErrorResponse(BaseModel):
    success: Literal[False] = False
    error: ErrorDetails
    meta: ResponseMetadata
