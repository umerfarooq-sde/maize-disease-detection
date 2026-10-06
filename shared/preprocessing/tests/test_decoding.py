"""Validation/color handling tests on generated files with explicit metadata."""

from collections.abc import Callable
from io import BytesIO

import numpy as np
import pytest
from PIL import Image, ImageCms

from maizedoctor_preprocessing import (
    ErrorCode,
    PreprocessingConfig,
    PreprocessingError,
    preprocess_image,
)


@pytest.mark.parametrize(
    ("image_format", "media_type", "filename"),
    [
        ("PNG", "image/png", "leaf.PNG"),
        ("JPEG", "image/jpeg", "leaf.JPEG"),
        ("WEBP", "image/webp", "leaf.webp"),
    ],
)
def test_valid_formats_are_decoded_and_reported(
    encode_image: Callable[..., bytes],
    no_segmentation: PreprocessingConfig,
    image_format: str,
    media_type: str,
    filename: str,
) -> None:
    encoded = encode_image(Image.new("RGB", (40, 32), (110, 55, 20)), image_format)
    result = preprocess_image(encoded, no_segmentation, media_type=media_type, filename=filename)
    assert result.standardized_rgb.shape == (32, 40, 3)
    assert result.standardized_rgb.dtype == np.uint8
    assert result.metadata.source_format == image_format


@pytest.mark.parametrize("mode", ["L", "LA", "P", "RGBA", "CMYK"])
def test_grayscale_palette_alpha_and_cmyk_standardize_to_rgb(
    encode_image: Callable[..., bytes], no_segmentation: PreprocessingConfig, mode: str
) -> None:
    if mode == "L":
        image, expected = Image.new("L", (32, 32), 80), (80, 80, 80)
    elif mode == "LA":
        image, expected = Image.new("LA", (32, 32), (80, 128)), (167, 167, 167)
    elif mode == "P":
        image = Image.new("P", (32, 32), 1)
        image.putpalette([0, 0, 0, 110, 40, 20] + [0, 0, 0] * 254)
        expected = (110, 40, 20)
    elif mode == "RGBA":
        image, expected = Image.new("RGBA", (32, 32), (110, 40, 20, 128)), (182, 147, 137)
    else:
        image, expected = Image.new("CMYK", (32, 32), (0, 255, 255, 0)), (255, 0, 0)
    data = encode_image(image, "JPEG" if mode == "CMYK" else "PNG")
    result = preprocess_image(data, no_segmentation)
    np.testing.assert_array_equal(result.standardized_rgb[15, 15], expected)


def test_palette_transparency_is_composited_without_leaking_hidden_colors(
    encode_image: Callable[..., bytes],
    no_segmentation: PreprocessingConfig,
) -> None:
    image = Image.new("P", (32, 32), 0)
    image.putpalette([250, 5, 10, 50, 80, 120] + [0, 0, 0] * 254)
    image.putpixel((16, 16), 1)
    result = preprocess_image(encode_image(image, transparency=0), no_segmentation)
    np.testing.assert_array_equal(result.standardized_rgb[0, 0], (255, 255, 255))
    np.testing.assert_array_equal(result.standardized_rgb[16, 16], (50, 80, 120))


def test_exif_orientation_is_applied_before_oriented_mask(
    encode_image: Callable[..., bytes],
    no_segmentation: PreprocessingConfig,
) -> None:
    image = Image.new("RGB", (48, 32), (120, 40, 20))
    exif = Image.Exif()
    exif[274] = 6
    encoded = encode_image(image, "JPEG", exif=exif)
    mask = np.zeros((48, 32), dtype=np.bool_)
    mask[8:35, 8:25] = True
    result = preprocess_image(encoded, no_segmentation, foreground_mask=mask)
    assert result.metadata.encoded_size == (48, 32)
    assert result.metadata.oriented_size == (32, 48)
    assert result.standardized_rgb.shape == (48, 32, 3)
    np.testing.assert_array_equal(result.foreground_mask, mask)


def test_valid_embedded_srgb_profile_is_applied(
    encode_image: Callable[..., bytes],
    no_segmentation: PreprocessingConfig,
) -> None:
    profile = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
    image = Image.new("RGB", (32, 32), (130, 80, 50))
    result = preprocess_image(encode_image(image, icc_profile=profile), no_segmentation)
    assert result.metadata.color_profile_applied
    np.testing.assert_array_equal(result.standardized_rgb[10, 10], (130, 80, 50))


@pytest.mark.parametrize(
    "bad_profile",
    [b"invalid profile", b"x" * 262_145],
    ids=["invalid-profile", "oversized-profile"],
)
def test_invalid_color_profile_fails_safely(
    encode_image: Callable[..., bytes],
    bad_profile: bytes,
) -> None:
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(encode_image(Image.new("RGB", (32, 32)), icc_profile=bad_profile))
    assert caught.value.code == ErrorCode.INVALID_COLOR_PROFILE


@pytest.mark.parametrize("invalid", [b"", b"not an image", bytearray(b"\x89PNG")])
def test_invalid_encoded_input_is_rejected_without_raw_input(invalid: bytes) -> None:
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(invalid)
    assert caught.value.code in {ErrorCode.INVALID_INPUT, ErrorCode.UNSUPPORTED_FORMAT}
    assert "not an image" not in str(caught.value)


@pytest.mark.parametrize("image_format", ["GIF", "BMP", "TIFF"])
def test_unsupported_formats_are_rejected(
    encode_image: Callable[..., bytes],
    image_format: str,
) -> None:
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(encode_image(Image.new("RGB", (32, 32)), image_format))
    assert caught.value.code == ErrorCode.UNSUPPORTED_FORMAT


@pytest.mark.parametrize(
    "headers",
    [
        {"media_type": "image/jpeg"},
        {"filename": "private-user.jpg"},
        {"media_type": "image/png; charset=utf-8"},
        {"filename": "leaf.txt"},
    ],
)
def test_claimed_type_and_extension_must_match_real_signature(
    encode_image: Callable[..., bytes],
    headers: dict[str, str],
) -> None:
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(encode_image(Image.new("RGB", (32, 32))), **headers)
    assert caught.value.code == ErrorCode.FORMAT_MISMATCH
    assert "private-user" not in str(caught.value)


@pytest.mark.parametrize("image_format", ["PNG", "JPEG", "WEBP"])
def test_truncated_image_is_rejected_even_if_decoder_could_tolerate_it(
    encode_image: Callable[..., bytes],
    image_format: str,
) -> None:
    data = encode_image(Image.new("RGB", (32, 32), (100, 50, 20)), image_format)
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(data[:-8])
    assert caught.value.code == ErrorCode.INVALID_IMAGE


def test_crc_corruption_with_valid_png_end_is_rejected(encode_image: Callable[..., bytes]) -> None:
    data = bytearray(encode_image(Image.new("RGB", (32, 32), (120, 30, 40))))
    # Changing an IDAT byte without its CRC keeps a plausible signature and valid end marker.
    data[data.index(b"IDAT") + 5] ^= 0xFF
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(bytes(data))
    assert caught.value.code == ErrorCode.INVALID_IMAGE


@pytest.mark.parametrize("image_format", ["PNG", "WEBP"])
def test_multiframe_images_are_rejected(image_format: str) -> None:
    buffer = BytesIO()
    Image.new("RGB", (32, 32), "red").save(
        buffer,
        format=image_format,
        save_all=True,
        append_images=[Image.new("RGB", (32, 32), "blue")],
        duration=100,
        loop=0,
    )
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(buffer.getvalue())
    assert caught.value.code == ErrorCode.ANIMATED_IMAGE


def test_byte_limit_and_pixel_limit_are_independently_authoritative(
    encode_image: Callable[..., bytes],
) -> None:
    data = encode_image(Image.new("RGB", (32, 32)))
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(data, PreprocessingConfig(max_bytes=len(data) - 1))
    assert caught.value.code == ErrorCode.IMAGE_TOO_LARGE
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(data, PreprocessingConfig(max_pixels=512))
    assert caught.value.code == ErrorCode.INVALID_DIMENSIONS
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(encode_image(Image.new("RGB", (15, 40))))
    assert caught.value.code == ErrorCode.INVALID_DIMENSIONS


def test_invalid_exif_orientation_is_rejected(encode_image: Callable[..., bytes]) -> None:
    exif = Image.Exif()
    exif[274] = 9
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(encode_image(Image.new("RGB", (32, 32)), "JPEG", exif=exif))
    assert caught.value.code == ErrorCode.INVALID_IMAGE


def test_16_bit_grayscale_scales_fixed_full_range_without_clipping_bright_lesions(
    encode_image: Callable[..., bytes],
    no_segmentation: PreprocessingConfig,
) -> None:
    row = np.array([0, 4096, 16384, 32768, 65535], dtype=np.uint16)
    values = np.repeat(np.tile(row, 4)[None, :], 32, axis=0)
    result = preprocess_image(encode_image(Image.fromarray(values)), no_segmentation)
    expected = np.repeat(np.array([0, 16, 64, 128, 255], dtype=np.uint8)[:, None], 3, axis=1)
    np.testing.assert_array_equal(result.standardized_rgb[0, :5], expected)
