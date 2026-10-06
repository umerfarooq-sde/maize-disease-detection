"""Generated synthetic fixtures: these are not real maize dataset validation."""

from collections.abc import Callable
from io import BytesIO
from typing import Any

import numpy as np
import pytest
from PIL import Image, ImageDraw

from maizedoctor_preprocessing import PreprocessingConfig, SegmentationConfig


@pytest.fixture
def encode_image() -> Callable[..., bytes]:
    def encode(image: Image.Image, image_format: str = "PNG", **options: Any) -> bytes:
        buffer = BytesIO()
        image.save(buffer, format=image_format, **options)
        return buffer.getvalue()

    return encode


@pytest.fixture
def synthetic_leaf() -> np.ndarray:
    """Elongated synthetic foreground with different lesion colors and a pale interior hole."""
    image = Image.new("RGB", (128, 192), (245, 245, 245))
    draw = ImageDraw.Draw(image)
    draw.polygon(
        [(64, 14), (82, 42), (91, 95), (80, 147), (64, 179), (47, 151), (37, 96), (45, 45)],
        fill=(45, 110, 50),
    )
    draw.polygon([(64, 14), (71, 27), (58, 27)], fill=(105, 62, 35))
    for y, color in [
        (44, (133, 74, 41)),
        (65, (211, 179, 46)),
        (87, (137, 139, 143)),
        (109, (30, 26, 24)),
        (131, (173, 77, 33)),
        (150, (245, 245, 245)),
    ]:
        draw.rectangle((57, y, 71, y + 9), fill=color)
    return np.array(image)


@pytest.fixture
def no_segmentation() -> PreprocessingConfig:
    return PreprocessingConfig(segmentation=SegmentationConfig(mode="disabled"))
