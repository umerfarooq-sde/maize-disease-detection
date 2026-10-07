"""Dataset configuration shared by intake, validation, and future training commands."""

import os
from collections.abc import Mapping
from pathlib import Path

from dotenv import dotenv_values

_TRAINING_ROOT = Path(__file__).resolve().parent


class DatasetConfigurationError(ValueError):
    """The configured dataset cannot be used without exposing private path values."""


def load_dataset_path(
    *,
    environment: Mapping[str, str] | None = None,
    dotenv_path: Path | None = None,
) -> Path:
    """Read an absolute existing directory without changing process environment.

    An explicitly present OS variable wins, including a blank value. The default
    dotenv file belongs to this training project regardless of the caller's cwd.
    Interpolation is disabled so unrelated environment values cannot alter paths.
    """
    variables = os.environ if environment is None else environment
    configured: str | None
    if "DATASET_PATH" in variables:
        configured = variables["DATASET_PATH"]
    else:
        try:
            values = dotenv_values(
                dotenv_path or _TRAINING_ROOT / ".env",
                encoding="utf-8",
                interpolate=False,
            )
        except (OSError, UnicodeError) as error:
            raise DatasetConfigurationError(
                "The dataset configuration file cannot be read."
            ) from error
        configured = values.get("DATASET_PATH")

    if configured is None or not configured.strip():
        raise DatasetConfigurationError("DATASET_PATH must be configured.")

    path = Path(configured.strip())
    if not path.is_absolute():
        raise DatasetConfigurationError("DATASET_PATH must be an absolute directory path.")

    try:
        is_directory = path.is_dir()
        resolved = path.resolve(strict=True) if is_directory else None
    except (OSError, ValueError) as error:
        raise DatasetConfigurationError("DATASET_PATH cannot be inspected.") from error
    if resolved is None:
        raise DatasetConfigurationError("DATASET_PATH must refer to an existing directory.")
    return resolved
