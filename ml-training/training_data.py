"""Dataset access always invokes shared preprocessing; augmentation is TRAIN only."""

from collections import defaultdict
from collections.abc import Callable, Sequence
from pathlib import Path
from typing import Literal, cast

import torch
from maizedoctor_preprocessing import PreprocessingConfig
from torch import Tensor
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms  # type: ignore[import-untyped]
from torchvision.transforms import InterpolationMode  # type: ignore[import-untyped]

from configuration import load_dataset_path
from dataset_preparation import SampleRecord
from preprocessing import preprocess_file

Split = Literal["train", "validation", "test"]
Sample = tuple[Tensor, int, str]


def training_augmentation(config: PreprocessingConfig) -> Callable[[Tensor], Tensor]:
    """No color jitter or repeated normalization on already normalized shared tensors."""
    fill = tuple(
        (channel / 255.0 - mean) / std
        for channel, mean, std in zip(
            config.background_rgb, config.normalization.mean, config.normalization.std, strict=True
        )
    )
    return cast(
        Callable[[Tensor], Tensor],
        transforms.Compose(
            [
                transforms.RandomHorizontalFlip(p=0.5),
                transforms.RandomAffine(
                    degrees=6,
                    translate=(0.02, 0.02),
                    scale=(0.97, 1.03),
                    interpolation=InterpolationMode.BILINEAR,
                    fill=fill,
                ),
            ]
        ),
    )


class MaizeDataset(Dataset[Sample]):
    def __init__(
        self,
        rows: Sequence[SampleRecord],
        config: PreprocessingConfig,
        *,
        split: Split,
        augment: bool = False,
        dataset_root: Path | None = None,
        augmentation: Callable[[Tensor], Tensor] | None = None,
    ) -> None:
        if split != "train" and (augment or augmentation is not None):
            raise ValueError("Validation and test augmentation is forbidden.")
        if augmentation is not None and not augment:
            raise ValueError("An augmentation callback requires explicit TRAIN augmentation.")
        self.rows = tuple(rows)
        self.config = config
        self.root = (
            load_dataset_path() if dataset_root is None else dataset_root.resolve(strict=True)
        )
        self.split = split
        self.augmentation = (augmentation or training_augmentation(config)) if augment else None

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> Sample:
        row = self.rows[index]
        source = (self.root / row.relative_path).resolve(strict=True)
        if not source.is_relative_to(self.root):
            raise ValueError("Sample path escapes the configured dataset.")
        result = preprocess_file(source, self.config)
        if result.metadata.image_hash != row.content_hash:
            raise ValueError("Sample bytes changed after the fixed dataset manifest.")
        tensor = result.to_tensor()
        if self.augmentation is not None:
            tensor = self.augmentation(tensor)
        if not torch.isfinite(tensor).all():
            raise ValueError("Sample values must remain finite.")
        return tensor, row.class_index, row.sample_id


def select_smoke_rows(rows: Sequence[SampleRecord], limit: int) -> tuple[SampleRecord, ...]:
    """Stable round-robin selection within an already fixed TRAIN or VALIDATION split."""
    if limit < 1:
        raise ValueError("Smoke subset size must be positive.")
    by_class: dict[int, list[SampleRecord]] = defaultdict(list)
    for row in sorted(rows, key=lambda sample: sample.sample_id):
        by_class[row.class_index].append(row)
    selected: list[SampleRecord] = []
    position = 0
    while len(selected) < min(limit, len(rows)):
        for class_index in sorted(by_class):
            if position < len(by_class[class_index]) and len(selected) < limit:
                selected.append(by_class[class_index][position])
        position += 1
    return tuple(selected)


def make_loader(dataset: MaizeDataset, *, batch_size: int, seed: int) -> DataLoader[Sample]:
    generator = torch.Generator().manual_seed(seed)
    return DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=dataset.split == "train" and dataset.augmentation is not None,
        generator=generator,
        num_workers=0,
        drop_last=False,
    )
