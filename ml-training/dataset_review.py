"""Configured, read-only real-data intake and exact shared-pipeline comparison."""

import argparse
import csv
import json
from collections import Counter
from collections.abc import Callable
from dataclasses import asdict
from pathlib import Path
from typing import cast

import numpy as np
from maizedoctor_preprocessing import PreprocessingError, SegmentationConfig
from maizedoctor_preprocessing.debug import write_debug_bundle
from maizedoctor_preprocessing.types import PreprocessingResult
from PIL import Image, ImageDraw

from configuration import load_dataset_path
from dataset_inventory import (
    IMAGE_EXTENSIONS,
    SUPPORTED_EXTENSIONS,
    ImageRecord,
    duplicate_groups,
    file_digest,
    inspect_image,
    near_duplicate_candidates,
    summarize,
)
from preprocessing import PreprocessingConfig, preprocess_file


def comparison_configs() -> tuple[PreprocessingConfig, PreprocessingConfig]:
    """Same shared package; compare policies without changing its canonical default."""
    enabled = PreprocessingConfig()
    disabled = PreprocessingConfig(segmentation=SegmentationConfig(mode="disabled"))
    return enabled, disabled


def validate_destination(root: Path, destination: Path) -> Path:
    resolved = destination.resolve()
    if resolved == root or root in resolved.parents:
        raise ValueError("Review output must be outside the source dataset.")
    if resolved.exists():
        raise ValueError("Review output must be a new directory; refusing overwrite.")
    return resolved


def result_facts(result: PreprocessingResult) -> dict[str, object]:
    width, height = result.metadata.oriented_size
    left, top, right, bottom = result.metadata.crop_bounds
    return {
        "segmentation": asdict(result.metadata.segmentation),
        "crop_bounds": result.metadata.crop_bounds,
        "crop_area_fraction": ((right - left) * (bottom - top)) / (width * height),
        "array_shape": result.model_array.shape,
        "dtype": str(result.model_array.dtype),
        "minimum": float(result.model_array.min()),
        "maximum": float(result.model_array.max()),
        "finite": bool(np.isfinite(result.model_array).all()),
        "config_hash": result.metadata.config_hash,
        "image_hash": result.metadata.image_hash,
        "warnings": result.metadata.warnings,
    }


def select_samples(records: list[ImageRecord], per_class: int) -> list[ImageRecord]:
    """Deterministic class-balanced extremes and evenly spread files, not a random split."""
    selected: list[ImageRecord] = []
    labels = sorted({r.label for r in records if r.label is not None})
    for label in labels:
        valid = [
            r
            for r in records
            if r.label == label
            and r.decode_error is None
            and r.preprocessing
            and "enabled" in r.preprocessing
        ]
        choices: list[ImageRecord] = []
        ranking: list[Callable[[ImageRecord], float]] = [
            lambda r: r.brightness or 0,
            lambda r: r.sharpness or 0,
            lambda r: (r.width or 0) * (r.height or 0),
            lambda r: (r.width or 1) / (r.height or 1),
            lambda r: r.size_bytes,
        ]
        for key in ranking:
            ordered = sorted(valid, key=key)
            choices.extend(ordered[:1] + ordered[-1:])
        segmented = []
        for record in valid:
            facts = cast(dict[str, object], (record.preprocessing or {})["enabled"])
            segmentation = cast(dict[str, object], facts["segmentation"])
            if segmentation["status"] == "segmented":
                segmented.append(record)
        choices.extend(segmented[: min(6, per_class)])
        if valid:
            choices.extend(
                valid[index] for index in np.linspace(0, len(valid) - 1, per_class).astype(int)
            )
        seen: set[str] = set()
        for record in choices:
            if record.relative_path not in seen and len(seen) < per_class:
                seen.add(record.relative_path)
                selected.append(record)
    return selected


def comparison_sheet(
    enabled: PreprocessingResult, disabled: PreprocessingResult, destination: Path, label: str
) -> None:
    mask = enabled.foreground_mask
    mask_pixels = (
        np.ones(enabled.standardized_rgb.shape[:2], dtype=np.uint8) * 255
        if mask is None
        else mask.astype(np.uint8) * 255
    )
    panels = [
        ("Original / standardized RGB", Image.fromarray(enabled.standardized_rgb)),
        ("Mask (white = kept)", Image.fromarray(mask_pixels).convert("RGB")),
        ("Extracted / background replaced", Image.fromarray(enabled.cropped_rgb)),
        ("Extraction final 224", Image.fromarray(enabled.prepared_rgb)),
        ("Full-frame final 224", Image.fromarray(disabled.prepared_rgb)),
    ]
    sheet = Image.new("RGB", (5 * 320, 370), "#f4f3ef")
    draw = ImageDraw.Draw(sheet)
    for index, (name, panel) in enumerate(panels):
        panel.thumbnail((312, 312), Image.Resampling.BILINEAR)
        x = index * 320
        draw.text((x + 4, 5), name, fill="black")
        sheet.paste(panel, (x + (320 - panel.width) // 2, 30 + (312 - panel.height) // 2))
    draw.text(
        (5, 345),
        f"{label}: {enabled.metadata.segmentation.status} / {enabled.metadata.segmentation.reason}",
        fill="black",
    )
    sheet.save(destination)


def run_review(destination: Path, *, samples_per_class: int = 20) -> dict[str, object]:
    if not 1 <= samples_per_class <= 100:
        raise ValueError("samples_per_class must be between 1 and 100")
    root = load_dataset_path()
    destination = validate_destination(root, destination)
    enabled, disabled = comparison_configs()
    destination.mkdir(parents=True)
    all_files = sorted(path for path in root.rglob("*") if path.is_file())
    initial = {
        p.relative_to(root).as_posix(): (p.stat().st_size, p.stat().st_mtime_ns) for p in all_files
    }
    records: list[ImageRecord] = []
    unsupported: list[str] = []
    for index, path in enumerate(all_files, 1):
        if path.suffix.lower() not in IMAGE_EXTENSIONS:
            unsupported.append(path.relative_to(root).as_posix())
            continue
        record = inspect_image(root, path)
        if record.extension not in SUPPORTED_EXTENSIONS:
            unsupported.append(record.relative_path)
        facts: dict[str, object] = {}
        for policy, config in [("enabled", enabled), ("disabled", disabled)]:
            try:
                result = preprocess_file(path, config)
                if result.metadata.image_hash != record.sha256:
                    raise RuntimeError("Source bytes changed between inventory and preprocessing.")
                facts[policy] = result_facts(result)
            except PreprocessingError as error:
                facts[f"{policy}_error"] = error.code.value
        record.preprocessing = facts
        records.append(record)
        with (destination / "inventory-progress.jsonl").open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(asdict(record), allow_nan=False) + "\n")
        if index % 250 == 0:
            print(f"Reviewed {index}/{len(all_files)} files", flush=True)
    exact = duplicate_groups(records)
    pixel = duplicate_groups(records, pixels=True)
    near = near_duplicate_candidates(records)
    by_path = {r.relative_path: r for r in records}
    selected = select_samples(records, samples_per_class)
    samples: list[dict[str, object]] = []
    for number, record in enumerate(selected):
        sample_dir = destination / "samples" / f"{number:03d}"
        sample_dir.mkdir(parents=True)
        result_enabled = preprocess_file(root / record.relative_path, enabled)
        result_disabled = preprocess_file(root / record.relative_path, disabled)
        write_debug_bundle(result_enabled, sample_dir / "extraction", enabled)
        write_debug_bundle(result_disabled, sample_dir / "full-frame", disabled)
        comparison_sheet(
            result_enabled,
            result_disabled,
            sample_dir / "comparison.png",
            record.label or "unlabeled",
        )
        samples.append(
            {
                "sample": f"samples/{number:03d}",
                "relative_path": record.relative_path,
                "label": record.label,
                "sha256": record.sha256,
                "facts": record.preprocessing,
            }
        )
    for label in sorted({r.label for r in selected if r.label}):
        label_samples = [sample for sample in samples if sample["label"] == label]
        sheet = Image.new("RGB", (5 * 224, len(label_samples) * 248), "#f4f3ef")
        draw = ImageDraw.Draw(sheet)
        for row, sample in enumerate(label_samples):
            with Image.open(destination / cast(str, sample["sample"]) / "comparison.png") as image:
                resized_panel = image.resize((1120, 224), Image.Resampling.BILINEAR)
                sheet.paste(resized_panel, (0, row * 248 + 24))
            draw.text((4, row * 248 + 4), str(sample["relative_path"]), fill="black")
        sheet.save(destination / f"overview-{label}.png")
        for page, start in enumerate(range(0, len(label_samples), 4)):
            sheet.crop((0, start * 248, 1120, min(len(label_samples), start + 4) * 248)).save(
                destination / f"overview-{label}-page-{page + 1}.png"
            )
    policy_counts: dict[str, Counter[str]] = {
        label: Counter() for label in sorted({r.label for r in records if r.label})
    }
    policy_counts["unlabeled"] = Counter()
    errors: list[dict[str, object]] = []
    for record in records:
        facts = record.preprocessing or {}
        if "enabled_error" in facts:
            errors.append({"path": record.relative_path, "error": facts["enabled_error"]})
        else:
            segmentation = cast(
                dict[str, object], cast(dict[str, object], facts["enabled"])["segmentation"]
            )
            policy_counts[record.label or "unlabeled"][
                f"{segmentation['status']}:{segmentation['reason']}"
            ] += 1
    summary = {
        **summarize(records),
        "dataset_path": str(root),
        "output_path": str(destination),
        "unsupported_files": unsupported,
        "exact_duplicate_groups": exact,
        "pixel_duplicate_groups": pixel,
        "exact_duplicate_excess": sum(len(group) - 1 for group in exact),
        "pixel_duplicate_excess": sum(len(group) - 1 for group in pixel),
        "conflicting_exact_groups": [
            group for group in exact if len({by_path[path].label for path in group}) > 1
        ],
        "conflicting_pixel_groups": [
            group for group in pixel if len({by_path[path].label for path in group}) > 1
        ],
        "near_duplicate_candidate_count": len(near),
        "near_duplicate_cross_label_count": sum(bool(pair["cross_label"]) for pair in near),
        "preprocessing_counts_by_class": {
            label: dict(counts) for label, counts in policy_counts.items()
        },
        "preprocessing_errors": errors,
        "enabled_configuration": enabled.model_dump(mode="json"),
        "enabled_hash": enabled.fingerprint,
        "disabled_configuration": disabled.model_dump(mode="json"),
        "disabled_hash": disabled.fingerprint,
        "sample_count": len(samples),
        "limitations": [
            "Perceptual hashes identify candidates, not confirmed parentage.",
            "No semantic lesion/leaf ground truth; visual review is separate.",
            "No partitions or augmentation created; all source images unchanged.",
        ],
    }
    final_files = sorted(path for path in root.rglob("*") if path.is_file())
    final = {
        p.relative_to(root).as_posix(): (p.stat().st_size, p.stat().st_mtime_ns)
        for p in final_files
    }
    if final != initial or any(file_digest(root / r.relative_path) != r.sha256 for r in records):
        raise RuntimeError("Dataset source contents changed during review.")
    summary["source_unchanged"] = True
    for filename, value in [
        ("summary.json", summary),
        ("inventory.json", [asdict(r) for r in records]),
        ("near-duplicate-candidates.json", near),
        ("samples.json", samples),
    ]:
        (destination / filename).write_text(
            json.dumps(value, indent=2, allow_nan=False) + "\n", encoding="utf-8"
        )
    with (destination / "inventory.csv").open("w", encoding="utf-8", newline="") as stream:
        fields = [
            "relative_path",
            "label",
            "split",
            "size_bytes",
            "sha256",
            "width",
            "height",
            "image_format",
            "mode",
            "decode_error",
        ]
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for record in records:
            inventory_row = asdict(record)
            writer.writerow({key: inventory_row[key] for key in fields})
    print(
        json.dumps(
            {
                "images": len(records),
                "samples": len(samples),
                "source_unchanged": True,
                "output": str(destination),
            },
            indent=2,
        ),
        flush=True,
    )
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Read configured dataset; compare shared preprocessing without training"
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="New ignored review directory outside source data",
    )
    parser.add_argument("--samples-per-class", type=int, default=20)
    args = parser.parse_args()
    if not 1 <= args.samples_per_class <= 100:
        parser.error("samples-per-class must be between 1 and 100")
    run_review(args.output, samples_per_class=args.samples_per_class)


if __name__ == "__main__":
    main()
