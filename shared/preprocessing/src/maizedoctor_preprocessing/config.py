"""Immutable versioned configuration; normalization is not tied to an invented model."""

import hashlib
import json
from pathlib import Path
from typing import Final, Literal, Self

from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator, model_validator

from maizedoctor_preprocessing.errors import ErrorCode, PreprocessingError

PREPROCESSING_VERSION: Final[Literal["1.0.0"]] = "1.0.0"


class Configuration(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid", allow_inf_nan=False, strict=True)


class NormalizationConfig(Configuration):
    mean: tuple[float, float, float] = (0.0, 0.0, 0.0)
    std: tuple[float, float, float] = (1.0, 1.0, 1.0)

    @field_validator("mean")
    @classmethod
    def bounded_mean(cls, values: tuple[float, float, float]) -> tuple[float, float, float]:
        if any(abs(value) > 10 for value in values):
            raise ValueError("Normalization mean must be bounded")
        return values

    @field_validator("std")
    @classmethod
    def positive_std(cls, values: tuple[float, float, float]) -> tuple[float, float, float]:
        if any(not 1e-6 <= value <= 10 for value in values):
            raise ValueError("Normalization standard deviation must be positive and bounded")
        return values


class SegmentationConfig(Configuration):
    mode: Literal["conservative", "disabled"] = "conservative"
    uncertain_policy: Literal["preserve", "raise"] = "preserve"
    max_working_dimension: int = Field(default=512, ge=64, le=1024)
    border_fraction: float = Field(default=0.03, ge=0.01, le=0.1)
    background_tolerance: float = Field(default=12.0, gt=0, le=40)
    max_border_variation: float = Field(default=6.0, gt=0, le=30)
    min_foreground_fraction: float = Field(default=0.02, gt=0, lt=0.5)
    max_foreground_fraction: float = Field(default=0.9, gt=0.5, lt=1)
    min_component_fraction: float = Field(default=0.001, gt=0, le=0.05)
    mask_margin_pixels: int = Field(default=2, ge=0, le=8)

    @model_validator(mode="after")
    def coherent_thresholds(self) -> Self:
        if self.max_border_variation > self.background_tolerance:
            raise ValueError("Border variation must not exceed background tolerance")
        return self


class PreprocessingConfig(Configuration):
    preprocessing_version: Literal["1.0.0"] = PREPROCESSING_VERSION
    target_height: int = Field(default=224, ge=16, le=2048)
    target_width: int = Field(default=224, ge=16, le=2048)
    max_bytes: int = Field(default=5 * 1024 * 1024, ge=1, le=32 * 1024 * 1024)
    max_pixels: int = Field(default=16_000_000, ge=256, le=16_000_000)
    min_side: int = Field(default=16, ge=1, le=1024)
    background_rgb: tuple[int, int, int] = (255, 255, 255)
    crop_padding_fraction: float = Field(default=0.08, ge=0, le=0.5)
    crop_min_padding_pixels: int = Field(default=2, ge=0, le=64)
    interpolation: Literal["bilinear", "bicubic", "lanczos"] = "bilinear"
    normalization: NormalizationConfig = Field(default_factory=NormalizationConfig)
    segmentation: SegmentationConfig = Field(default_factory=SegmentationConfig)

    @field_validator("background_rgb")
    @classmethod
    def valid_rgb(cls, values: tuple[int, int, int]) -> tuple[int, int, int]:
        if any(not 0 <= value <= 255 for value in values):
            raise ValueError("RGB channels must be in 0-255")
        return values

    @model_validator(mode="after")
    def coherent_dimensions(self) -> Self:
        if self.min_side * self.min_side > self.max_pixels:
            raise ValueError("Minimum dimensions exceed the pixel limit")
        return self

    @property
    def fingerprint(self) -> str:
        canonical = json.dumps(
            self.model_dump(mode="json"), sort_keys=True, separators=(",", ":"), allow_nan=False
        )
        return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def load_config(path: Path) -> PreprocessingConfig:
    try:
        with path.open("rb") as source:
            encoded = source.read(65_537)
        if len(encoded) > 65_536:
            raise PreprocessingError(ErrorCode.INVALID_CONFIGURATION)
        return PreprocessingConfig.model_validate_json(encoded)
    except (OSError, ValidationError, UnicodeError):
        raise PreprocessingError(ErrorCode.INVALID_CONFIGURATION) from None
