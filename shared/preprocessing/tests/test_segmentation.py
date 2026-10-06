"""Geometric/color stress tests use generated fixtures, not clinical efficacy evidence."""

from collections.abc import Callable

import numpy as np
import pytest
from PIL import Image, ImageDraw

from maizedoctor_preprocessing import (
    ErrorCode,
    PreprocessingConfig,
    PreprocessingError,
    SegmentationConfig,
    preprocess_image,
)


def test_diseased_regions_and_leaf_tip_are_preserved(
    encode_image: Callable[..., bytes], synthetic_leaf: np.ndarray
) -> None:
    result = preprocess_image(encode_image(Image.fromarray(synthetic_leaf)))
    assert result.metadata.segmentation.status == "segmented"
    assert result.metadata.segmentation.method == "border_connected"
    assert result.foreground_mask is not None
    left, top, _, _ = result.metadata.crop_bounds
    for x, y in [(64, 16), (64, 47), (64, 68), (64, 90), (64, 112), (64, 134), (64, 153)]:
        assert result.foreground_mask[y, x], (x, y)
        np.testing.assert_array_equal(result.cropped_rgb[y - top, x - left], synthetic_leaf[y, x])
    # Outward protection includes a pixel just beyond the side, rather than eroding the leaf.
    assert result.foreground_mask[96, 36]
    assert not result.foreground_mask[0, 0]
    np.testing.assert_array_equal(result.cropped_rgb[0, 0], (255, 255, 255))
    assert result.metadata.segmentation.component_count == 1
    assert "leaf_identity_unverified" in result.metadata.warnings


@pytest.mark.parametrize(
    "foreground_color",
    [(133, 74, 41), (211, 179, 46), (137, 139, 143), (30, 26, 24), (173, 77, 33)],
    ids=["brown", "yellow", "gray", "dead-tissue", "rust"],
)
def test_foreground_extraction_is_independent_of_green_hue(
    encode_image: Callable[..., bytes], foreground_color: tuple[int, int, int]
) -> None:
    image = Image.new("RGB", (128, 192), "white")
    ImageDraw.Draw(image).ellipse((44, 20, 85, 175), fill=foreground_color)
    result = preprocess_image(encode_image(image))
    assert result.metadata.segmentation.status == "segmented"
    assert result.foreground_mask is not None
    assert result.foreground_mask[96, 64]
    assert result.foreground_mask[23, 64]
    assert not result.foreground_mask[0, 0]


@pytest.mark.parametrize("scene", ["uniform", "heterogeneous", "edge-touching", "multiple"])
def test_ambiguous_extraction_preserves_full_frame(
    encode_image: Callable[..., bytes], scene: str
) -> None:
    image = Image.new("RGB", (128, 192), "white")
    draw = ImageDraw.Draw(image)
    if scene == "heterogeneous":
        draw.rectangle((0, 0, 63, 191), fill=(120, 65, 170))
        draw.ellipse((45, 40, 85, 150), fill=(150, 90, 40))
    elif scene == "edge-touching":
        draw.rectangle((40, 0, 85, 130), fill=(50, 105, 40))
    elif scene == "multiple":
        draw.ellipse((15, 30, 45, 150), fill=(110, 80, 40))
        draw.ellipse((80, 30, 110, 150), fill=(110, 80, 40))
    result = preprocess_image(encode_image(image))
    assert result.metadata.segmentation.status == "fallback"
    assert result.foreground_mask is None
    assert result.metadata.crop_bounds == (0, 0, 128, 192)
    np.testing.assert_array_equal(result.cropped_rgb, np.array(image))
    assert any(warning.startswith("segmentation_fallback:") for warning in result.metadata.warnings)


def test_strict_policy_returns_safe_error_instead_of_inventing_leaf(
    encode_image: Callable[..., bytes],
) -> None:
    config = PreprocessingConfig(segmentation=SegmentationConfig(uncertain_policy="raise"))
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(encode_image(Image.new("RGB", (32, 32), "white")), config)
    assert caught.value.code == ErrorCode.SEGMENTATION_UNCERTAIN


def test_disabled_segmentation_keeps_image_and_reports_it(
    encode_image: Callable[..., bytes],
    synthetic_leaf: np.ndarray,
    no_segmentation: PreprocessingConfig,
) -> None:
    result = preprocess_image(encode_image(Image.fromarray(synthetic_leaf)), no_segmentation)
    assert result.metadata.segmentation.status == "disabled"
    assert result.foreground_mask is None
    np.testing.assert_array_equal(result.cropped_rgb, synthetic_leaf)


def test_provided_mask_controls_crop_without_color_filtering_or_caller_mutation(
    encode_image: Callable[..., bytes],
) -> None:
    image = Image.new("RGB", (96, 64), (130, 80, 65))
    mask = np.zeros((64, 96), dtype=np.bool_)
    mask[10:50, 20:70] = True
    before = mask.copy()
    result = preprocess_image(encode_image(image), foreground_mask=mask)
    assert result.metadata.segmentation.method == "provided_mask"
    np.testing.assert_array_equal(result.foreground_mask, before)
    np.testing.assert_array_equal(mask, before)
    assert mask.flags.writeable
    assert result.foreground_mask is not mask
    assert result.metadata.crop_bounds[0] < 20
    assert result.metadata.crop_bounds[2] > 69


@pytest.mark.parametrize("kind", ["wrong-shape", "uint8", "list"])
def test_masks_must_match_oriented_dimensions_and_boolean_contract(
    encode_image: Callable[..., bytes], kind: str
) -> None:
    invalid = {
        "wrong-shape": np.ones((31, 32), dtype=np.bool_),
        "uint8": np.ones((32, 32), dtype=np.uint8),
        "list": [[True]],
    }[kind]
    with pytest.raises(PreprocessingError) as caught:
        preprocess_image(encode_image(Image.new("RGB", (32, 32))), foreground_mask=invalid)
    assert caught.value.code == ErrorCode.INVALID_MASK


def test_empty_mask_is_uncertain_and_alpha_preserves_partial_transparency(
    encode_image: Callable[..., bytes],
) -> None:
    rgb = Image.new("RGB", (32, 32), (100, 50, 20))
    empty = preprocess_image(encode_image(rgb), foreground_mask=np.zeros((32, 32), dtype=np.bool_))
    assert empty.metadata.segmentation.reason == "empty_provided_mask"
    rgba = Image.new("RGBA", (32, 32), (200, 30, 40, 0))
    rgba.putpixel((16, 16), (200, 30, 40, 1))
    result = preprocess_image(encode_image(rgba))
    assert result.metadata.segmentation.method == "alpha"
    assert result.foreground_mask is not None
    assert result.foreground_mask[16, 16]
    assert not result.foreground_mask[0, 0]


def test_fully_transparent_image_falls_back_explicitly(encode_image: Callable[..., bytes]) -> None:
    result = preprocess_image(encode_image(Image.new("RGBA", (32, 32), (20, 40, 60, 0))))
    assert result.metadata.segmentation.reason == "empty_alpha"
    assert result.foreground_mask is None
    assert np.all(result.standardized_rgb == 255)
