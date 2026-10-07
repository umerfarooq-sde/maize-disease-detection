"""Read-only dataset facts and duplicate candidates; no labels or splits are changed."""

import hashlib
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import cast

import cv2
import numpy as np
from numpy.typing import NDArray
from PIL import Image, ImageOps, UnidentifiedImageError

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff", ".gif"}
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
SPLIT_NAMES = {"train", "training", "val", "valid", "validation", "test", "testing"}


@dataclass
class ImageRecord:
    relative_path: str
    label: str | None
    split: str | None
    extension: str
    size_bytes: int
    modified_ns: int
    sha256: str
    width: int | None = None
    height: int | None = None
    image_format: str | None = None
    mode: str | None = None
    frames: int | None = None
    pixel_hash: str | None = None
    phash: int | None = None
    dhash: int | None = None
    brightness: float | None = None
    sharpness: float | None = None
    metadata_keys: tuple[str, ...] = ()
    decode_error: str | None = None
    preprocessing: dict[str, object] | None = None


def infer_label(relative: Path) -> tuple[str | None, str | None]:
    """Use literal directory labels; recognize split containers without claiming officiality."""
    parts = relative.parts
    if len(parts) < 2:
        return None, None
    if parts[0].casefold() in SPLIT_NAMES:
        return (parts[1] if len(parts) >= 3 else None), parts[0]
    return parts[0], None


def file_digest(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def inspect_image(root: Path, path: Path) -> ImageRecord:
    relative = path.relative_to(root)
    label, split = infer_label(relative)
    before = path.stat()
    record = ImageRecord(
        relative.as_posix(),
        label,
        split,
        path.suffix.lower(),
        before.st_size,
        before.st_mtime_ns,
        file_digest(path),
    )
    try:
        with Image.open(path) as image:
            record.width, record.height = image.size
            record.image_format = image.format
            record.mode = image.mode
            record.frames = getattr(image, "n_frames", 1)
            record.metadata_keys = tuple(sorted(str(key) for key in image.info))
            # Bound analysis buffers; unsupported giant originals are still inventoried.
            if image.width * image.height > 16_000_000:
                record.decode_error = "PIXEL_LIMIT_FOR_ANALYSIS"
                return record
            image.verify()
        with Image.open(path) as image:
            image.load()
            rgb = ImageOps.exif_transpose(image).convert("RGB")
            pixel_payload = f"{rgb.width}x{rgb.height}:RGB:".encode() + rgb.tobytes()
            record.pixel_hash = hashlib.sha256(pixel_payload).hexdigest()
            thumbnail = rgb.resize((32, 32), Image.Resampling.BILINEAR).convert("L")
            gray = np.asarray(thumbnail, dtype=np.float32)
            low_frequency = cv2.dct(gray)[:8, :8].flatten()
            median = float(np.median(low_frequency[1:]))
            record.phash = bits_to_int(low_frequency > median)
            gradient = np.asarray(rgb.resize((9, 8)).convert("L"), dtype=np.int16)
            record.dhash = bits_to_int((gradient[:, 1:] > gradient[:, :-1]).flatten())
            record.brightness = float(gray.mean())
            record.sharpness = float(cv2.Laplacian(gray, cv2.CV_32F).var())
    except (UnidentifiedImageError, OSError, ValueError, SyntaxError, Image.DecompressionBombError):
        record.decode_error = "UNREADABLE_IMAGE"
    after = path.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise RuntimeError("A source image changed during inventory; review aborted.")
    return record


def bits_to_int(bits: NDArray[np.bool_]) -> int:
    value = 0
    for bit in bits:
        value = (value << 1) | int(bool(bit))
    return value


def duplicate_groups(records: list[ImageRecord], *, pixels: bool = False) -> list[list[str]]:
    groups: dict[str, list[str]] = defaultdict(list)
    for record in records:
        key = record.pixel_hash if pixels else record.sha256
        if key is not None:
            groups[key].append(record.relative_path)
    return sorted(
        (sorted(paths) for paths in groups.values() if len(paths) > 1), key=lambda p: p[0]
    )


class HashTree:
    """BK tree for practical Hamming-distance search; candidates are not ground truth."""

    def __init__(self, value: int) -> None:
        self.value = value
        self.indices: list[int] = []
        self.children: dict[int, HashTree] = {}

    def add(self, value: int, index: int) -> None:
        node = self
        while distance := (node.value ^ value).bit_count():
            child = node.children.get(distance)
            if child is None:
                child = HashTree(value)
                node.children[distance] = child
            node = child
        node.indices.append(index)

    def query(self, value: int, radius: int) -> list[int]:
        found: list[int] = []
        pending = [self]
        while pending:
            node = pending.pop()
            distance = (node.value ^ value).bit_count()
            if distance <= radius:
                found.extend(node.indices)
            pending.extend(
                child
                for edge, child in node.children.items()
                if distance - radius <= edge <= distance + radius
            )
        return found


def near_duplicate_candidates(records: list[ImageRecord]) -> list[dict[str, object]]:
    usable = [(index, r) for index, r in enumerate(records) if r.phash is not None]
    if not usable:
        return []
    tree = HashTree(cast(int, usable[0][1].phash))
    pairs: list[dict[str, object]] = []
    for index, record in usable:
        assert record.phash is not None and record.dhash is not None
        for other_index in tree.query(record.phash, 4):
            other = records[other_index]
            assert other.phash is not None and other.dhash is not None
            if record.sha256 == other.sha256 or record.pixel_hash == other.pixel_hash:
                continue
            dhash_distance = (record.dhash ^ other.dhash).bit_count()
            if dhash_distance <= 6:
                pairs.append(
                    {
                        "first": other.relative_path,
                        "second": record.relative_path,
                        "phash_distance": (record.phash ^ other.phash).bit_count(),
                        "dhash_distance": dhash_distance,
                        "cross_label": other.label != record.label,
                    }
                )
        tree.add(record.phash, index)
    return pairs


def summarize(records: list[ImageRecord]) -> dict[str, object]:
    readable = [r for r in records if r.width is not None and r.height is not None]
    return {
        "images": len(records),
        "class_counts": dict(sorted(Counter(r.label for r in records if r.label).items())),
        "unlabeled_images": sum(r.label is None for r in records),
        "split_folder_counts": dict(Counter(r.split for r in records if r.split)),
        "extensions": dict(Counter(r.extension for r in records)),
        "decoded_formats": dict(Counter(r.image_format for r in records if r.image_format)),
        "dimensions": dict(Counter(f"{r.width}x{r.height}" for r in readable)),
        "modes": dict(Counter(r.mode for r in records if r.mode)),
        "aspect_ratios": numeric_summary(
            [cast(int, r.width) / cast(int, r.height) for r in readable]
        ),
        "bytes": numeric_summary([float(r.size_bytes) for r in records]),
        "total_bytes": sum(r.size_bytes for r in records),
        "tiny_side_under_32": [
            r.relative_path for r in readable if min(cast(int, r.width), cast(int, r.height)) < 32
        ],
        "low_resolution_under_128": sum(
            min(cast(int, r.width), cast(int, r.height)) < 128 for r in readable
        ),
        "over_5_mib": [r.relative_path for r in records if r.size_bytes > 5 * 1024 * 1024],
        "over_16m_pixels": [
            r.relative_path
            for r in readable
            if cast(int, r.width) * cast(int, r.height) > 16_000_000
        ],
        "decode_errors": [asdict(r) for r in records if r.decode_error],
    }


def numeric_summary(values: list[float]) -> dict[str, float | None]:
    if not values:
        return {name: None for name in ["min", "median", "p95", "max"]}
    return {
        "min": min(values),
        "median": float(np.median(values)),
        "p95": float(np.percentile(values, 95)),
        "max": max(values),
    }
