"""Bounded full decode, EXIF orientation, RGB/sRGB and explicit alpha handling."""

from io import BytesIO
from pathlib import PurePath
from typing import cast

import numpy as np
from PIL import Image, ImageCms, ImageOps, UnidentifiedImageError

from maizedoctor_preprocessing.config import PreprocessingConfig
from maizedoctor_preprocessing.errors import ErrorCode, PreprocessingError
from maizedoctor_preprocessing.types import DecodedImage, RGBArray

MEDIA_TYPES = {"JPEG": "image/jpeg", "PNG": "image/png", "WEBP": "image/webp"}
EXTENSIONS = {".jpg": "JPEG", ".jpeg": "JPEG", ".png": "PNG", ".webp": "WEBP"}


def _signature(data: bytes) -> str:
    if data.startswith(b"\xff\xd8\xff"):
        return "JPEG"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "PNG"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "WEBP"
    raise PreprocessingError(ErrorCode.UNSUPPORTED_FORMAT)


def _check_dimensions(image: Image.Image, config: PreprocessingConfig) -> None:
    width, height = image.size
    if min(width, height) < config.min_side or width * height > config.max_pixels:
        raise PreprocessingError(ErrorCode.INVALID_DIMENSIONS)
    if getattr(image, "n_frames", 1) != 1:
        raise PreprocessingError(ErrorCode.ANIMATED_IMAGE)


def _standardize(
    image: Image.Image, config: PreprocessingConfig, image_format: str
) -> DecodedImage:
    encoded_size = image.size
    orientation = image.getexif().get(274, 1)
    if not isinstance(orientation, int) or orientation not in range(1, 9):
        raise PreprocessingError(ErrorCode.INVALID_IMAGE)
    oriented = ImageOps.exif_transpose(image)
    has_alpha = "A" in oriented.getbands() or "transparency" in oriented.info
    alpha_image = oriented.convert("RGBA").getchannel("A") if has_alpha else None
    profile = oriented.info.get("icc_profile")
    # Pillow's I;16 -> RGB conversion clips to 255. Preserve grayscale gradations
    # using the fixed unsigned 16-bit range, never per-image contrast stretching.
    if oriented.mode.startswith("I;16") or (image_format == "PNG" and oriented.mode == "I"):
        intensity = np.asarray(oriented, dtype=np.int64)
        if intensity.min() < 0 or intensity.max() > 65535:
            raise PreprocessingError(ErrorCode.INVALID_IMAGE)
        scaled = ((intensity + 128) // 257).astype(np.uint8)
        oriented = Image.fromarray(scaled)
    if profile:
        if not isinstance(profile, bytes) or len(profile) > 262_144:
            raise PreprocessingError(ErrorCode.INVALID_COLOR_PROFILE)
        try:
            source = oriented if oriented.mode in {"L", "RGB", "CMYK"} else oriented.convert("RGB")
            rgb_image = ImageCms.profileToProfile(
                source,
                ImageCms.ImageCmsProfile(BytesIO(profile)),
                ImageCms.createProfile("sRGB"),
                renderingIntent=ImageCms.Intent.PERCEPTUAL,
                outputMode="RGB",
            )
        except (ImageCms.PyCMSError, OSError, ValueError, TypeError):
            raise PreprocessingError(ErrorCode.INVALID_COLOR_PROFILE) from None
    else:
        rgb_image = oriented.convert("RGB")
    if rgb_image is None:
        raise PreprocessingError(ErrorCode.INVALID_COLOR_PROFILE)
    if alpha_image is not None:
        background = Image.new("RGB", rgb_image.size, config.background_rgb)
        rgb_image = Image.composite(rgb_image, background, alpha_image)
    rgb = cast(RGBArray, np.array(rgb_image, dtype=np.uint8, copy=True))
    alpha = None if alpha_image is None else cast(RGBArray, np.array(alpha_image, dtype=np.uint8))
    return DecodedImage(rgb, alpha, image_format, encoded_size, bool(profile))


def decode_image(
    data: bytes,
    config: PreprocessingConfig,
    *,
    media_type: str | None = None,
    filename: str | None = None,
) -> DecodedImage:
    if not isinstance(data, bytes) or not data:
        raise PreprocessingError(ErrorCode.INVALID_INPUT)
    if len(data) > config.max_bytes:
        raise PreprocessingError(ErrorCode.IMAGE_TOO_LARGE)
    image_format = _signature(data)
    if media_type is not None and media_type != MEDIA_TYPES[image_format]:
        raise PreprocessingError(ErrorCode.FORMAT_MISMATCH)
    if filename is not None and EXTENSIONS.get(PurePath(filename).suffix.lower()) != image_format:
        raise PreprocessingError(ErrorCode.FORMAT_MISMATCH)
    # Reject missing end markers independently of Pillow's global truncated-file option.
    if image_format == "JPEG" and not data.endswith(b"\xff\xd9"):
        raise PreprocessingError(ErrorCode.INVALID_IMAGE)
    if image_format == "PNG" and not data.endswith(b"\x00\x00\x00\x00IEND\xaeB`\x82"):
        raise PreprocessingError(ErrorCode.INVALID_IMAGE)
    if image_format == "WEBP" and int.from_bytes(data[4:8], "little") + 8 != len(data):
        raise PreprocessingError(ErrorCode.INVALID_IMAGE)
    try:
        with Image.open(BytesIO(data), formats=[image_format]) as image:
            _check_dimensions(image, config)
            if image.format != image_format:
                raise PreprocessingError(ErrorCode.FORMAT_MISMATCH)
            image.verify()
        with Image.open(BytesIO(data), formats=[image_format]) as image:
            _check_dimensions(image, config)
            image.load()
            return _standardize(image, config, image_format)
    except (UnidentifiedImageError, OSError, ValueError, SyntaxError, Image.DecompressionBombError):
        raise PreprocessingError(ErrorCode.INVALID_IMAGE) from None
