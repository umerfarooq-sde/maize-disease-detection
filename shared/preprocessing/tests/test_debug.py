"""Development-only debug artifacts must stay explicit, bounded and non-destructive."""

import json
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from maizedoctor_preprocessing import (
    ErrorCode,
    PreprocessingConfig,
    PreprocessingError,
    preprocess_image,
)
from maizedoctor_preprocessing.debug import write_debug_bundle


def test_debug_bundle_contains_viewable_stages_and_full_configuration(
    encode_image: Callable[..., bytes],
    synthetic_leaf: np.ndarray,
    tmp_path: Path,
) -> None:
    config = PreprocessingConfig()
    result = preprocess_image(encode_image(Image.fromarray(synthetic_leaf)), config)
    output = tmp_path / "synthetic-review"
    assert write_debug_bundle(result, output, config) == output
    assert {item.name for item in output.iterdir()} == {
        "standardized.png",
        "mask.png",
        "prepared.png",
        "contact-sheet.png",
        "metadata.json",
    }
    with Image.open(output / "contact-sheet.png") as sheet:
        assert sheet.size == (960, 704)
        sheet.load()
    with Image.open(output / "mask.png") as mask:
        np.testing.assert_array_equal(np.array(mask) > 0, result.foreground_mask)
    metadata = json.loads((output / "metadata.json").read_text(encoding="utf-8"))
    assert metadata["configuration"] == config.model_dump(mode="json")
    assert metadata["result"]["config_hash"] == config.fingerprint
    assert metadata["result"]["segmentation"]["method"] == "border_connected"
    before = {item.name: item.read_bytes() for item in output.iterdir()}
    with pytest.raises(PreprocessingError) as caught:
        write_debug_bundle(result, output, config)
    assert caught.value.code == ErrorCode.DEBUG_OUTPUT_UNAVAILABLE
    assert {item.name: item.read_bytes() for item in output.iterdir()} == before


def test_debug_bundle_rejects_mismatched_configuration_before_creating_output(
    encode_image: Callable[..., bytes],
    tmp_path: Path,
) -> None:
    result = preprocess_image(encode_image(Image.new("RGB", (32, 32))))
    destination = tmp_path / "must-not-exist"
    with pytest.raises(PreprocessingError) as caught:
        write_debug_bundle(result, destination, PreprocessingConfig(target_width=128))
    assert caught.value.code == ErrorCode.INVALID_CONFIGURATION
    assert not destination.exists()


def test_debug_cli_emits_safe_json_and_never_overwrites_existing_output(
    encode_image: Callable[..., bytes],
    tmp_path: Path,
) -> None:
    source = tmp_path / "synthetic.png"
    source.write_bytes(encode_image(Image.new("RGB", (32, 32), (140, 70, 40))))
    output = tmp_path / "review"
    command = [
        sys.executable,
        "-m",
        "maizedoctor_preprocessing",
        str(source),
        "--output",
        str(output),
    ]
    completed = subprocess.run(command, capture_output=True, text=True, check=False, timeout=30)
    assert completed.returncode == 0, completed.stderr
    response = json.loads(completed.stdout)
    assert response["success"] is True
    assert response["preprocessing_version"] == "1.0.0"
    assert str(source) not in completed.stdout
    metadata_before = (output / "metadata.json").read_bytes()
    duplicate = subprocess.run(command, capture_output=True, text=True, check=False, timeout=30)
    assert duplicate.returncode == 1
    assert json.loads(duplicate.stderr)["error"]["code"] == "DEBUG_OUTPUT_UNAVAILABLE"
    assert (output / "metadata.json").read_bytes() == metadata_before
    source.write_bytes(b"private-filename-image-content-not-for-logs")
    invalid = subprocess.run(command, capture_output=True, text=True, check=False, timeout=30)
    assert invalid.returncode == 1
    assert json.loads(invalid.stderr)["error"]["code"] == "UNSUPPORTED_FORMAT"
    assert "private-filename-image-content" not in invalid.stderr
    assert "Traceback" not in invalid.stderr
