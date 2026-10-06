"""Load operational settings without requiring unused provider credentials."""

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
            "LOG_LEVEL and AI_SERVICE_TOKEN."
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
