"""Array contracts and immutable metadata; arrays become read-only before return."""

from dataclasses import dataclass
from typing import TYPE_CHECKING, Literal

import numpy as np
from numpy.typing import NDArray

if TYPE_CHECKING:
    import torch

RGBArray = NDArray[np.uint8]
MaskArray = NDArray[np.bool_]
ModelArray = NDArray[np.float32]
Bounds = tuple[int, int, int, int]


@dataclass(frozen=True)
class DecodedImage:
    rgb: RGBArray
    alpha: RGBArray | None
    format: str
    encoded_size: tuple[int, int]
    color_profile_applied: bool


@dataclass(frozen=True)
class SegmentationReport:
    status: Literal["segmented", "fallback", "disabled"]
    method: Literal["alpha", "provided_mask", "border_connected", "none"]
    reason: str | None
    foreground_fraction: float | None
    border_variation: float | None
    component_count: int | None


@dataclass(frozen=True)
class SegmentationResult:
    mask: MaskArray | None
    report: SegmentationReport


@dataclass(frozen=True)
class PreprocessingMetadata:
    preprocessing_version: str
    config_hash: str
    image_hash: str
    foreground_mask_hash: str | None
    source_format: str
    encoded_size: tuple[int, int]
    oriented_size: tuple[int, int]
    crop_bounds: Bounds
    content_bounds: Bounds
    target_size: tuple[int, int]
    color_profile_applied: bool
    segmentation: SegmentationReport
    warnings: tuple[str, ...]
    library_versions: tuple[tuple[str, str], ...]


@dataclass(frozen=True)
class PreprocessingResult:
    model_array: ModelArray
    standardized_rgb: RGBArray
    foreground_mask: MaskArray | None
    cropped_rgb: RGBArray
    prepared_rgb: RGBArray
    metadata: PreprocessingMetadata

    def to_tensor(self) -> "torch.Tensor":
        """Optional CPU float32 CHW adapter; never transforms or adds a batch axis."""
        import torch

        return torch.from_numpy(self.model_array.copy())
