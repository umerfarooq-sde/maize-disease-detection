"""One deterministic encoded-image -> RGB CHW float32 implementation."""

import hashlib
import math
import struct
from pathlib import Path
from typing import cast

import cv2
import numpy as np
from PIL import Image
from PIL import __version__ as pillow_version

from maizedoctor_preprocessing.config import PreprocessingConfig
from maizedoctor_preprocessing.decoding import decode_image
from maizedoctor_preprocessing.errors import ErrorCode, PreprocessingError
from maizedoctor_preprocessing.segmentation import segment_foreground
from maizedoctor_preprocessing.types import (
    Bounds,
    MaskArray,
    ModelArray,
    PreprocessingMetadata,
    PreprocessingResult,
    RGBArray,
)

RESAMPLING = {
    "bilinear": Image.Resampling.BILINEAR,
    "bicubic": Image.Resampling.BICUBIC,
    "lanczos": Image.Resampling.LANCZOS,
}


def _crop(
    rgb: RGBArray, mask: MaskArray | None, config: PreprocessingConfig
) -> tuple[RGBArray, Bounds]:
    height, width = rgb.shape[:2]
    if mask is None:
        return rgb.copy(), (0, 0, width, height)
    # Only allocate coordinates for occupied rows/columns, not every leaf pixel.
    ys = np.flatnonzero(mask.any(axis=1))
    xs = np.flatnonzero(mask.any(axis=0))
    padding = max(
        config.crop_min_padding_pixels,
        math.ceil(
            max(int(xs.max() - xs.min()), int(ys.max() - ys.min())) * config.crop_padding_fraction
        ),
    )
    left, top = max(0, int(xs.min()) - padding), max(0, int(ys.min()) - padding)
    right, bottom = (
        min(width, int(xs.max()) + padding + 1),
        min(height, int(ys.max()) + padding + 1),
    )
    cropped = rgb[top:bottom, left:right].copy()
    crop_mask = mask[top:bottom, left:right]
    cropped[~crop_mask] = config.background_rgb
    return cropped, (left, top, right, bottom)


def _letterbox(rgb: RGBArray, config: PreprocessingConfig) -> tuple[RGBArray, Bounds, bool]:
    height, width = rgb.shape[:2]
    scale = min(config.target_width / width, config.target_height / height)
    resized_width = min(config.target_width, max(1, round(width * scale)))
    resized_height = min(config.target_height, max(1, round(height * scale)))
    image = Image.fromarray(rgb).resize(
        (resized_width, resized_height), RESAMPLING[config.interpolation]
    )
    canvas = Image.new("RGB", (config.target_width, config.target_height), config.background_rgb)
    left, top = (
        (config.target_width - resized_width) // 2,
        (config.target_height - resized_height) // 2,
    )
    canvas.paste(image, (left, top))
    return (
        cast(RGBArray, np.array(canvas, dtype=np.uint8)),
        (left, top, left + resized_width, top + resized_height),
        scale > 1,
    )


def preprocess_image(
    data: bytes,
    config: PreprocessingConfig | None = None,
    *,
    media_type: str | None = None,
    filename: str | None = None,
    foreground_mask: MaskArray | None = None,
) -> PreprocessingResult:
    """Masks, if provided, describe the EXIF-oriented frame; no augmentation occurs."""
    configuration = config if config is not None else PreprocessingConfig()
    decoded = decode_image(data, configuration, media_type=media_type, filename=filename)
    try:
        segmentation = segment_foreground(
            decoded.rgb, decoded.alpha, configuration.segmentation, foreground_mask
        )
        cropped, crop_bounds = _crop(decoded.rgb, segmentation.mask, configuration)
        prepared, content_bounds, upscaled = _letterbox(cropped, configuration)
    except cv2.error:
        raise PreprocessingError(ErrorCode.INVALID_IMAGE) from None
    values = prepared.astype(np.float32) / np.float32(255.0)
    mean = np.asarray(configuration.normalization.mean, dtype=np.float32)
    std = np.asarray(configuration.normalization.std, dtype=np.float32)
    model_array = cast(ModelArray, np.ascontiguousarray(((values - mean) / std).transpose(2, 0, 1)))
    if not np.isfinite(model_array).all():
        raise PreprocessingError(ErrorCode.INVALID_CONFIGURATION)
    warnings = ["leaf_identity_unverified"]
    if segmentation.report.status == "fallback":
        warnings.append(f"segmentation_fallback:{segmentation.report.reason}")
    if upscaled:
        warnings.append("image_upscaled")
    metadata = PreprocessingMetadata(
        preprocessing_version=configuration.preprocessing_version,
        config_hash=configuration.fingerprint,
        image_hash=hashlib.sha256(data).hexdigest(),
        foreground_mask_hash=(
            hashlib.sha256(
                struct.pack(">II", *foreground_mask.shape) + foreground_mask.tobytes(order="C")
            ).hexdigest()
            if foreground_mask is not None
            else None
        ),
        source_format=decoded.format,
        encoded_size=decoded.encoded_size,
        oriented_size=(decoded.rgb.shape[1], decoded.rgb.shape[0]),
        crop_bounds=crop_bounds,
        content_bounds=content_bounds,
        target_size=(configuration.target_width, configuration.target_height),
        color_profile_applied=decoded.color_profile_applied,
        segmentation=segmentation.report,
        warnings=tuple(warnings),
        library_versions=(
            ("numpy", np.__version__),
            ("pillow", pillow_version),
            ("opencv", cv2.__version__),
        ),
    )
    for array in (decoded.rgb, segmentation.mask, cropped, prepared, model_array):
        if array is not None:
            array.setflags(write=False)
    return PreprocessingResult(
        model_array, decoded.rgb, segmentation.mask, cropped, prepared, metadata
    )


def preprocess_file(path: Path, config: PreprocessingConfig | None = None) -> PreprocessingResult:
    """A bounded file reader calling the exact same encoded-byte entrypoint."""
    configuration = config if config is not None else PreprocessingConfig()
    try:
        with path.open("rb") as source:
            data = source.read(configuration.max_bytes + 1)
    except OSError:
        raise PreprocessingError(ErrorCode.FILE_UNAVAILABLE) from None
    return preprocess_image(data, configuration, filename=path.name)
