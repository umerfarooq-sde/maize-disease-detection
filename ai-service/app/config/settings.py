"""Load server-only settings; artifact compatibility is verified in the lifespan."""

import ipaddress
import re
from pathlib import Path
from typing import Literal, Self

from pydantic import Field, SecretStr, ValidationError, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

SERVICE_ROOT = Path(__file__).resolve().parents[2]


class ConfigurationError(Exception):
    """Safe startup failure: never include rejected settings or their values."""

    def __init__(self) -> None:
        super().__init__(
            "Invalid AI service configuration; check ENVIRONMENT, HOST, PORT, "
            "LOG_LEVEL, AI_SERVICE_TOKEN and model/inference settings."
        )


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=SERVICE_ROOT / ".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
        frozen=True,
        populate_by_name=True,
        hide_input_in_errors=True,
    )

    environment: Literal["development", "test", "production"] = Field(
        default="development", validation_alias="ENVIRONMENT"
    )
    host: str = Field(default="127.0.0.1", validation_alias="HOST")
    port: int = Field(default=8000, ge=1, le=65535, validation_alias="PORT")
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = Field(
        default="INFO", validation_alias="LOG_LEVEL"
    )
    ai_service_token: SecretStr = Field(
        default=SecretStr(""), validation_alias="AI_SERVICE_TOKEN", repr=False
    )
    inference_enabled: bool = Field(default=True, validation_alias="INFERENCE_ENABLED")
    model_path: Path | None = Field(default=None, validation_alias="MODEL_PATH", repr=False)
    model_metadata_path: Path | None = Field(
        default=None, validation_alias="MODEL_METADATA_PATH", repr=False
    )
    model_metadata_sha256: str = Field(default="", validation_alias="MODEL_METADATA_SHA256")
    model_version: str = Field(default="", validation_alias="MODEL_VERSION", max_length=120)
    preprocessing_version: str = Field(
        default="", validation_alias="PREPROCESSING_VERSION", max_length=30
    )
    inference_threads: int = Field(default=2, ge=1, le=8, validation_alias="INFERENCE_THREADS")
    inference_max_concurrency: int = Field(
        default=1, ge=1, le=4, validation_alias="INFERENCE_MAX_CONCURRENCY"
    )
    inference_upload_timeout_seconds: float = Field(
        default=10,
        ge=1,
        le=60,
        allow_inf_nan=False,
        validation_alias="INFERENCE_UPLOAD_TIMEOUT_SECONDS",
    )
    confidence_policy_path: Path | None = Field(
        default=None, validation_alias="CONFIDENCE_POLICY_PATH", repr=False
    )
    confidence_policy_sha256: str = Field(default="", validation_alias="CONFIDENCE_POLICY_SHA256")

    @field_validator("model_path", "model_metadata_path", "confidence_policy_path", mode="before")
    @classmethod
    def resolve_artifact_path(cls, value: object) -> object:
        if value is None or value == "":
            return None
        if not isinstance(value, str | Path):
            raise ValueError("Artifact paths must be filesystem paths")
        path = Path(value)
        return (path if path.is_absolute() else SERVICE_ROOT / path).resolve()

    @field_validator("model_metadata_sha256", "confidence_policy_sha256")
    @classmethod
    def validate_artifact_hash(cls, value: str) -> str:
        if value and not re.fullmatch(r"[a-f0-9]{64}", value):
            raise ValueError("Artifact hashes must be lowercase SHA-256 values")
        return value

    @field_validator("host")
    @classmethod
    def validate_host(cls, value: str) -> str:
        if value == "localhost":
            return value
        try:
            return str(ipaddress.ip_address(value))
        except ValueError:
            raise ValueError("HOST must be an IP address or localhost") from None

    @field_validator("ai_service_token")
    @classmethod
    def validate_token(cls, value: SecretStr) -> SecretStr:
        token = value.get_secret_value()
        if token and not re.fullmatch(r"[A-Za-z0-9_-]{43,256}", token):
            raise ValueError("Use a randomly generated base64url service token")
        return value

    @model_validator(mode="after")
    def require_network_token(self) -> Self:
        loopback = self.host == "localhost" or ipaddress.ip_address(self.host).is_loopback
        if (self.environment == "production" or not loopback) and not self.ai_service_token:
            raise ValueError("Production and non-loopback binding require a service token")
        return self


def load_settings(env_file: Path | None = SERVICE_ROOT / ".env") -> Settings:
    """OS environment overrides the service-local dotenv file; load once per app."""
    try:
        return Settings(_env_file=env_file)
    except (ValidationError, OSError, UnicodeError):
        raise ConfigurationError() from None
