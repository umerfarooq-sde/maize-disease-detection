"""One deterministic encoded-byte contract, independent of caller or training state."""

import hashlib
import json
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np
import pytest
from PIL import Image
from pydantic import ValidationError

from maizedoctor_preprocessing import (
    PREPROCESSING_VERSION,
    ErrorCode,
    NormalizationConfig,
    PreprocessingConfig,
    PreprocessingError,
    SegmentationConfig,
    load_config,
    preprocess_file,
    preprocess_image,
)


def test_model_ready_contract_is_rgb_chw_float32_normalized_and_readonly(
    encode_image: Callable[..., bytes],
) -> None:
    config = PreprocessingConfig(
        target_height=16,
        target_width=16,
        normalization=NormalizationConfig(mean=(0.1, 0.2, 0.3), std=(0.5, 0.25, 0.2)),
        segmentation=SegmentationConfig(mode="disabled"),
    )
    result = preprocess_image(encode_image(Image.new("RGB", (32, 32), (100, 150, 200))), config)
    expected = (np.array([100, 150, 200], dtype=np.float32) / 255 - [0.1, 0.2, 0.3]) / [
        0.5,
        0.25,
        0.2,
    ]
    assert result.model_array.shape == (3, 16, 16)
    assert result.model_array.dtype == np.float32
    assert result.model_array.flags.c_contiguous
    np.testing.assert_allclose(result.model_array[:, 8, 8], expected, rtol=1e-6)
    assert np.isfinite(result.model_array).all()
    for array in [
        result.standardized_rgb,
        result.cropped_rgb,
        result.prepared_rgb,
        result.model_array,
    ]:
        assert not array.flags.writeable
        with pytest.raises(ValueError):
            array.flat[0] = 0
    assert result.metadata.preprocessing_version == PREPROCESSING_VERSION
    assert result.metadata.config_hash == config.fingerprint
    assert {name for name, _ in result.metadata.library_versions} == {"numpy", "pillow", "opencv"}


@pytest.mark.parametrize("size", [(96, 32), (32, 96), (17, 33), (2048, 32)])
def test_letterbox_keeps_aspect_ratio_and_padding_explicit(
    encode_image: Callable[..., bytes],
    size: tuple[int, int],
) -> None:
    config = PreprocessingConfig(
        target_width=128,
        target_height=96,
        background_rgb=(240, 230, 220),
        segmentation=SegmentationConfig(mode="disabled"),
    )
    result = preprocess_image(encode_image(Image.new("RGB", size, (100, 50, 25))), config)
    assert result.metadata.oriented_size == size
    assert result.metadata.crop_bounds == (0, 0, *size)
    assert result.model_array.shape == (3, 96, 128)
    left, top, right, bottom = result.metadata.content_bounds
    resized_width, resized_height = right - left, bottom - top
    scale = min(128 / size[0], 96 / size[1])
    assert resized_width == max(1, round(size[0] * scale))
    assert resized_height == max(1, round(size[1] * scale))
    np.testing.assert_array_equal(
        result.prepared_rgb[(top + bottom) // 2, (left + right) // 2], (100, 50, 25)
    )
    if top > 0 or left > 0:
        np.testing.assert_array_equal(result.prepared_rgb[0, 0], config.background_rgb)
    assert ("image_upscaled" in result.metadata.warnings) == (scale > 1)


def test_repeated_and_concurrent_calls_are_identical(
    encode_image: Callable[..., bytes],
    synthetic_leaf: np.ndarray,
) -> None:
    encoded = encode_image(Image.fromarray(synthetic_leaf))
    config = PreprocessingConfig(target_width=96, target_height=160)
    reference = preprocess_image(encoded, config)
    with ThreadPoolExecutor(max_workers=4) as workers:
        results = list(workers.map(lambda _: preprocess_image(encoded, config), range(8)))
    for result in results:
        np.testing.assert_array_equal(result.model_array, reference.model_array)
        np.testing.assert_array_equal(result.foreground_mask, reference.foreground_mask)
        assert result.metadata == reference.metadata
    assert reference.metadata.image_hash == hashlib.sha256(encoded).hexdigest()


def test_file_and_bytes_entrypoints_produce_identical_representation(
    encode_image: Callable[..., bytes],
    synthetic_leaf: np.ndarray,
    tmp_path: Path,
) -> None:
    data = encode_image(Image.fromarray(synthetic_leaf))
    source = tmp_path / "synthetic-maize-like.png"
    source.write_bytes(data)
    file_result = preprocess_file(source)
    byte_result = preprocess_image(data, filename=source.name)
    np.testing.assert_array_equal(file_result.model_array, byte_result.model_array)
    assert file_result.metadata == byte_result.metadata
    with pytest.raises(PreprocessingError) as caught:
        preprocess_file(tmp_path / "private-person-unavailable.png")
    assert caught.value.code == ErrorCode.FILE_UNAVAILABLE
    assert "private-person" not in str(caught.value)


def test_external_mask_provenance_distinguishes_equal_area_masks(
    encode_image: Callable[..., bytes],
) -> None:
    image = Image.new("RGB", (64, 64), (100, 80, 50))
    for x in range(32, 64):
        for y in range(64):
            image.putpixel((x, y), (30, 60, 90))
    encoded = encode_image(image)
    mask_left = np.zeros((64, 64), dtype=np.bool_)
    mask_left[10:54, 8:28] = True
    mask_right = np.zeros((64, 64), dtype=np.bool_)
    mask_right[10:54, 36:56] = True
    left = preprocess_image(encoded, foreground_mask=mask_left)
    right = preprocess_image(encoded, foreground_mask=mask_right)
    repeat = preprocess_image(encoded, foreground_mask=mask_left.copy())
    assert left.metadata.foreground_mask_hash != right.metadata.foreground_mask_hash
    assert left.metadata.foreground_mask_hash == repeat.metadata.foreground_mask_hash
    assert left.metadata.config_hash == right.metadata.config_hash
    assert left.metadata.image_hash == right.metadata.image_hash
    assert not np.array_equal(left.model_array, right.model_array)


def test_torch_adapter_preserves_chw_values_and_isolates_mutation(
    encode_image: Callable[..., bytes],
) -> None:
    torch = pytest.importorskip("torch")
    result = preprocess_image(encode_image(Image.new("RGB", (32, 32), (120, 90, 50))))
    tensor = result.to_tensor()
    assert tensor.shape == result.model_array.shape
    assert tensor.dtype == torch.float32
    assert tensor.device.type == "cpu"
    np.testing.assert_array_equal(tensor.numpy(), result.model_array)
    original = result.model_array.copy()
    tensor[0, 0, 0] = -123
    np.testing.assert_array_equal(result.model_array, original)


@pytest.mark.parametrize(
    "configuration",
    [
        {"target_height": 15},
        {"target_width": "224"},
        {"max_bytes": 0},
        {"max_pixels": 255},
        {"min_side": 1024, "max_pixels": 256},
        {"preprocessing_version": "9.0.0"},
        {"background_rgb": (256, 0, 0)},
        {"interpolation": "nearest"},
        {"augmentation": True},
    ],
)
def test_invalid_configuration_is_not_silently_coerced(configuration: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        PreprocessingConfig(**configuration)


@pytest.mark.parametrize("std", [(0.0, 1.0, 1.0), (float("nan"), 1.0, 1.0), (11.0, 1.0, 1.0)])
def test_normalization_rejects_zero_nonfinite_and_unbounded_std(
    std: tuple[float, float, float],
) -> None:
    with pytest.raises(ValidationError):
        NormalizationConfig(std=std)


def test_configuration_is_immutable_and_hash_tracks_actual_settings(tmp_path: Path) -> None:
    config = PreprocessingConfig()
    with pytest.raises(ValidationError):
        config.target_height = 256
    with pytest.raises(ValidationError):
        config.segmentation.mode = "disabled"
    assert config.fingerprint == PreprocessingConfig().fingerprint
    assert config.fingerprint != PreprocessingConfig(target_height=256).fingerprint
    assert config.fingerprint != PreprocessingConfig(crop_min_padding_pixels=4).fingerprint
    target = tmp_path / "preprocessing.json"
    target.write_text(config.model_dump_json(), encoding="utf-8")
    assert load_config(target) == config
    assert load_config(target).fingerprint == config.fingerprint
    assert len(config.fingerprint) == 64
    reordered = dict(reversed(list(config.model_dump(mode="json").items())))
    target.write_text(json.dumps(reordered), encoding="utf-8")
    assert load_config(target).fingerprint == config.fingerprint


@pytest.mark.parametrize(
    "content",
    ["not JSON", '{"api_secret":"never-echo-me"}', "x" * 65_537],
    ids=["malformed-json", "unknown-secret-field", "oversized-config"],
)
def test_config_file_errors_are_bounded_and_safe(tmp_path: Path, content: str) -> None:
    target = tmp_path / "private-config.json"
    target.write_text(content, encoding="utf-8")
    with pytest.raises(PreprocessingError) as caught:
        load_config(target)
    assert caught.value.code == ErrorCode.INVALID_CONFIGURATION
    assert "private-config" not in str(caught.value)
    assert "never-echo-me" not in str(caught.value)
