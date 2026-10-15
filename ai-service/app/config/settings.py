"""Load server-only settings; artifact compatibility is verified in the lifespan."""

import ipaddress
import re
import sys
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
            "LOG_LEVEL, AI_SERVICE_TOKEN and model/inference/retrieval settings."
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
    rag_enabled: bool = Field(default=False, validation_alias="RAG_ENABLED")
    database_url: SecretStr = Field(
        default=SecretStr(""), validation_alias="DATABASE_URL", repr=False
    )
    gemini_api_key: SecretStr = Field(
        default=SecretStr(""), validation_alias="GEMINI_API_KEY", repr=False
    )
    embedding_model: str = Field(default="", validation_alias="EMBEDDING_MODEL", max_length=100)
    embedding_version: str = Field(default="", validation_alias="EMBEDDING_VERSION", max_length=160)
    embedding_dimensions: int = Field(
        default=768, ge=128, le=3072, validation_alias="EMBEDDING_DIMENSIONS"
    )
    embedding_timeout_seconds: float = Field(
        default=8, ge=1, le=20, allow_inf_nan=False, validation_alias="EMBEDDING_TIMEOUT_SECONDS"
    )
    rag_chunk_chars: int = Field(default=1000, ge=200, le=1500, validation_alias="RAG_CHUNK_CHARS")
    rag_chunk_overlap: int = Field(default=120, ge=0, le=300, validation_alias="RAG_CHUNK_OVERLAP")
    rag_max_concurrency: int = Field(default=4, ge=1, le=8, validation_alias="RAG_MAX_CONCURRENCY")
    generation_enabled: bool = Field(default=False, validation_alias="GENERATION_ENABLED")
    gemini_model: str = Field(default="", max_length=100, validation_alias="GEMINI_MODEL")
    generation_timeout_seconds: float = Field(
        default=12, ge=1, le=30, allow_inf_nan=False, validation_alias="GENERATION_TIMEOUT_SECONDS"
    )
    generation_max_concurrency: int = Field(
        default=2, ge=1, le=4, validation_alias="GENERATION_MAX_CONCURRENCY"
    )
    generation_context_chars: int = Field(
        default=6000, ge=1000, le=12000, validation_alias="GENERATION_CONTEXT_CHARS"
    )
    generation_max_chunks: int = Field(
        default=8, ge=1, le=10, validation_alias="GENERATION_MAX_CHUNKS"
    )
    generation_corpus_path: Path | None = Field(
        default=None, validation_alias="GENERATION_CORPUS_PATH", repr=False
    )
    generation_review_path: Path | None = Field(
        default=None, validation_alias="GENERATION_REVIEW_PATH", repr=False
    )

    @field_validator("generation_corpus_path", "generation_review_path", mode="before")
    @classmethod
    def resolve_generation_path(cls, value: object) -> object:
        return cls.resolve_artifact_path(value)

    @model_validator(mode="after")
    def require_generation_configuration(self) -> Self:
        if self.generation_enabled:
            if not self.rag_enabled or not self.gemini_api_key or not self.ai_service_token:
                raise ValueError(
                    "Generation requires authenticated retrieval and provider configuration"
                )
            if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{1,99}", self.gemini_model):
                raise ValueError("An explicit generation model is required")
            if self.generation_corpus_path is None or self.generation_review_path is None:
                raise ValueError("Generation requires the pinned reviewed corpus")
        return self

    @model_validator(mode="after")
    def validate_retrieval_configuration(self) -> Self:
        if self.rag_chunk_overlap >= self.rag_chunk_chars:
            raise ValueError("Chunk overlap must be smaller than chunk size")
        if self.rag_enabled:
            from urllib.parse import urlsplit

            parsed = urlsplit(self.database_url.get_secret_value())
            if (
                parsed.scheme not in {"postgresql", "postgres"}
                or not parsed.hostname
                or not parsed.path.strip("/")
            ):
                raise ValueError("Retrieval requires a PostgreSQL connection")
            if self.environment == "production":
                from urllib.parse import parse_qs

                parameters = parse_qs(parsed.query)
                if {"host", "hostaddr", "port"}.intersection(parameters):
                    raise ValueError("Database endpoint must be specified in the URL authority")
                if parsed.hostname not in {"localhost", "127.0.0.1", "::1"} and (
                    parameters.get("sslmode")
                    not in [["require"], ["prefer"], ["verify-ca"], ["verify-full"]]
                    or "ssl" in parameters
                ):
                    raise ValueError("Production remote PostgreSQL requires verified TLS")
            if not self.gemini_api_key or not self.ai_service_token:
                raise ValueError("Retrieval requires server credentials")
            if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{1,99}", self.embedding_model):
                raise ValueError("Configure an explicit Google text embedding model")
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{1,159}", self.embedding_version):
                raise ValueError("Configure an explicit embedding version")
        return self

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
        if self.environment == "production" and (
            sys.version_info[:2] != (3, 11) or sys.version_info[:3] < (3, 11, 17)
        ):
            raise ValueError("Production requires a maintained Python 3.11.17+ security patch")
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
