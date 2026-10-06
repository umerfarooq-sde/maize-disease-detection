"""Conservative foreground extraction independent of green/healthy tissue hue."""

from typing import cast

import cv2
import numpy as np
from numpy.typing import NDArray
from PIL import Image

from maizedoctor_preprocessing.config import SegmentationConfig
from maizedoctor_preprocessing.errors import ErrorCode, PreprocessingError
from maizedoctor_preprocessing.types import (
    MaskArray,
    RGBArray,
    SegmentationReport,
    SegmentationResult,
)


def _perimeter_connected(candidate: MaskArray) -> MaskArray:
    """Keep all candidate components touching the image perimeter, never interior holes."""
    _, labels = cv2.connectedComponents(candidate.astype(np.uint8), connectivity=8)
    label_array = cast(NDArray[np.int32], labels)
    edge_labels = np.unique(
        np.concatenate((label_array[0], label_array[-1], label_array[:, 0], label_array[:, -1]))
    )
    edge_labels = edge_labels[edge_labels != 0]
    return np.isin(label_array, edge_labels)


def _fallback(
    config: SegmentationConfig,
    reason: str,
    *,
    variation: float | None = None,
    fraction: float | None = None,
    components: int | None = None,
) -> SegmentationResult:
    if config.uncertain_policy == "raise":
        raise PreprocessingError(ErrorCode.SEGMENTATION_UNCERTAIN)
    return SegmentationResult(
        None,
        SegmentationReport("fallback", "none", reason, fraction, variation, components),
    )


def segment_foreground(
    rgb: RGBArray,
    alpha: RGBArray | None,
    config: SegmentationConfig,
    provided_mask: MaskArray | None = None,
) -> SegmentationResult:
    height, width = rgb.shape[:2]
    if provided_mask is not None:
        if (
            not isinstance(provided_mask, np.ndarray)
            or provided_mask.dtype != np.bool_
            or provided_mask.shape != (height, width)
        ):
            raise PreprocessingError(ErrorCode.INVALID_MASK)
        if not provided_mask.any():
            return _fallback(config, "empty_provided_mask")
        mask = provided_mask.copy()
        return SegmentationResult(
            mask,
            SegmentationReport("segmented", "provided_mask", None, float(mask.mean()), None, None),
        )
    if config.mode == "disabled":
        return SegmentationResult(
            None, SegmentationReport("disabled", "none", None, None, None, None)
        )
    if alpha is not None and not (alpha == 255).all():
        mask = alpha > 0
        if not mask.any():
            return _fallback(config, "empty_alpha")
        return SegmentationResult(
            mask,
            SegmentationReport("segmented", "alpha", None, float(mask.mean()), None, None),
        )

    scale = min(1.0, config.max_working_dimension / max(width, height))
    working_size = (max(2, round(width * scale)), max(2, round(height * scale)))
    working = cast(
        RGBArray,
        np.array(Image.fromarray(rgb).resize(working_size, Image.Resampling.BILINEAR)),
    )
    lab = cast(
        NDArray[np.float32], cv2.cvtColor(working.astype(np.float32) / 255, cv2.COLOR_RGB2LAB)
    )
    work_height, work_width = lab.shape[:2]
    border_size = max(1, round(min(work_height, work_width) * config.border_fraction))
    border = np.zeros((work_height, work_width), dtype=np.bool_)
    border[:border_size] = border[-border_size:] = True
    border[:, :border_size] = border[:, -border_size:] = True
    background_color = np.median(lab[border], axis=0)
    distance = np.linalg.norm(lab - background_color, axis=2)
    variation = float(np.percentile(distance[border], 95))
    if variation > config.max_border_variation:
        return _fallback(config, "heterogeneous_border", variation=variation)

    background_candidate = distance <= config.background_tolerance
    mask = ~_perimeter_connected(background_candidate)
    fraction = float(mask.mean())
    if not config.min_foreground_fraction <= fraction <= config.max_foreground_fraction:
        return _fallback(
            config, "implausible_foreground_area", variation=variation, fraction=fraction
        )
    if mask[0].any() or mask[-1].any() or mask[:, 0].any() or mask[:, -1].any():
        return _fallback(
            config, "foreground_touches_border", variation=variation, fraction=fraction
        )
    count, _, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), connectivity=8)
    component_count = sum(
        int(stats[index, cv2.CC_STAT_AREA]) / mask.size >= config.min_component_fraction
        for index in range(1, count)
    )
    if component_count != 1:
        return _fallback(
            config,
            "multiple_foreground_regions",
            variation=variation,
            fraction=fraction,
            components=component_count,
        )
    # Outward-only safety margin: never erode, blur or select only a green component.
    margin = config.mask_margin_pixels
    if margin:
        kernel = np.ones((2 * margin + 1, 2 * margin + 1), dtype=np.uint8)
        mask = cv2.dilate(mask.astype(np.uint8), kernel) > 0
    source_mask = (
        np.array(
            Image.fromarray(mask.astype(np.uint8) * 255).resize(
                (width, height), Image.Resampling.NEAREST
            )
        )
        > 0
    )
    return SegmentationResult(
        source_mask,
        SegmentationReport(
            "segmented",
            "border_connected",
            None,
            float(source_mask.mean()),
            variation,
            component_count,
        ),
    )
