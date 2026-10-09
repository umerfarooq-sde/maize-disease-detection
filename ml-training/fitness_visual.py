"""Validation-only model diagnostics; local image sheets must never be redistributed.

Temporary RGB perturbations are evaluation probes, not stored validation augmentation
or a new preprocessing implementation. All model inputs use the pinned shared package.
Grad-CAM is coarse diagnostic evidence, not a lesion mask or a causal explanation.
"""

import argparse
import csv
import hashlib
import io
import json
import textwrap
from collections.abc import Sequence
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import cast

import cv2
import numpy as np
import torch
from maizedoctor_preprocessing import PreprocessingConfig, PreprocessingError, load_config
from maizedoctor_preprocessing.types import Bounds, RGBArray
from numpy.typing import NDArray
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps
from torch import Tensor, nn

from configuration import load_dataset_path
from dataset_preparation import DatasetManifest, SampleRecord, load_manifest
from evaluation import compute_metrics
from model import build_model, read_checkpoint, restore_checkpoint, set_feature_training
from preprocessing import preprocess_file, preprocess_image
from train import write_json
from training_data import training_augmentation


@dataclass(frozen=True)
class Perturbation:
    name: str
    operation: str
    amount: float


PERTURBATIONS = (
    Perturbation("brightness_0.8", "brightness", 0.8),
    Perturbation("brightness_1.2", "brightness", 1.2),
    Perturbation("contrast_0.8", "contrast", 0.8),
    Perturbation("contrast_1.2", "contrast", 1.2),
    Perturbation("rotation_minus_5", "rotation", -5.0),
    Perturbation("rotation_plus_5", "rotation", 5.0),
    Perturbation("scale_0.97", "scale", 0.97),
    Perturbation("jpeg_quality_70", "jpeg", 70.0),
    Perturbation("blur_radius_0.7", "blur", 0.7),
    Perturbation("horizontal_flip", "flip", 1.0),
)


def perturb_image(
    rgb: RGBArray, specification: Perturbation, background: tuple[int, int, int]
) -> bytes:
    """Preserve the source: operate on a detached temporary RGB image and encode bytes."""
    image = Image.fromarray(rgb)
    match specification.operation:
        case "brightness":
            image = ImageEnhance.Brightness(image).enhance(specification.amount)
        case "contrast":
            image = ImageEnhance.Contrast(image).enhance(specification.amount)
        case "rotation":
            image = image.rotate(
                specification.amount,
                resample=Image.Resampling.BILINEAR,
                expand=False,
                fillcolor=background,
            )
        case "scale":
            if not 0 < specification.amount <= 1:
                raise ValueError("The declared scale probe must shrink without cropping.")
            size = (
                max(1, round(image.width * specification.amount)),
                max(1, round(image.height * specification.amount)),
            )
            smaller = image.resize(size, Image.Resampling.BILINEAR)
            canvas = Image.new("RGB", image.size, background)
            canvas.paste(
                smaller, ((image.width - smaller.width) // 2, (image.height - smaller.height) // 2)
            )
            image = canvas
        case "blur":
            image = image.filter(ImageFilter.GaussianBlur(specification.amount))
        case "flip":
            image = ImageOps.mirror(image)
        case "jpeg":
            pass
        case _:
            raise ValueError("Unknown diagnostic perturbation.")
    buffer = io.BytesIO()
    if specification.operation == "jpeg":
        image.save(buffer, format="JPEG", quality=int(specification.amount), subsampling=2)
    else:
        image.save(buffer, format="PNG")
    return buffer.getvalue()


def grad_cam(model: nn.Module, inputs: Tensor, target: int) -> NDArray[np.float32]:
    """Predicted-class Grad-CAM on the final feature block, at its actual spatial scale."""
    captured: list[Tensor] = []

    def capture(module: nn.Module, arguments: tuple[Tensor, ...], output: Tensor) -> None:
        output.retain_grad()
        captured.append(output)

    final = cast(nn.Sequential, model.features)[-1]
    handle = final.register_forward_hook(capture)
    was_training = model.training
    try:
        model.eval()
        model.zero_grad(set_to_none=True)
        logits = cast(Tensor, model(inputs.detach().clone().requires_grad_(True)))
        if logits.shape[0] != 1 or target not in range(logits.shape[1]):
            raise ValueError("Grad-CAM requires one image and a valid target class.")
        logits[0, target].backward()  # type: ignore[no-untyped-call]
        activation = captured[-1]
        gradient = activation.grad
        if gradient is None:
            raise ValueError("The selected feature block has no gradient.")
        weights = gradient.mean(dim=(2, 3), keepdim=True)
        coarse = (weights * activation).sum(dim=1, keepdim=True).relu()
        expanded = torch.nn.functional.interpolate(
            coarse, size=inputs.shape[-2:], mode="bilinear", align_corners=False
        )[0, 0]
        maximum = expanded.max()
        if maximum > 0:
            expanded = expanded / maximum
        result = cast(NDArray[np.float32], expanded.detach().cpu().numpy().copy())
        if not np.isfinite(result).all():
            raise ValueError("Grad-CAM became nonfinite.")
        return result
    finally:
        handle.remove()
        model.zero_grad(set_to_none=True)
        model.train(was_training)


def cam_geometry(cam: NDArray[np.float32], content_bounds: Bounds) -> dict[str, float | None]:
    """Border/padding statistics are geometrical; they do not identify leaf/background."""
    height, width = cam.shape
    border_size = max(1, round(min(height, width) * 0.1))
    border = np.zeros_like(cam, dtype=np.bool_)
    border[:border_size] = border[-border_size:] = True
    border[:, :border_size] = border[:, -border_size:] = True
    padding = np.ones_like(border)
    left, top, right, bottom = content_bounds
    padding[top:bottom, left:right] = False
    total = float(cam.sum())
    border_mass = float(cam[border].sum()) / total if total > 0 else None
    return {
        "positive_activation_mass": total,
        "border_pixel_fraction": float(border.mean()),
        "border_activation_fraction": border_mass,
        "border_enrichment_vs_uniform": border_mass / float(border.mean())
        if border_mass is not None
        else None,
        "letterbox_pixel_fraction": float(padding.mean()),
        "letterbox_activation_fraction": float(cam[padding].sum()) / total if total > 0 else None,
    }


def source_membership(row: SampleRecord) -> str:
    versions = {reference.dataset_version_id for reference in row.provenance.references}
    if any(version.startswith("277323/") for version in versions):
        return "PlantVillage_color_overlap"
    if any(version.startswith("967819/") for version in versions):
        return "Corn_collection_only_origin_not_independently_verified"
    return "source_membership_unmapped"


def inverse_for_display(tensor: Tensor, config: PreprocessingConfig) -> Image.Image:
    """Invert configured normalization ONLY to inspect actual TRAIN augmentation pixels."""
    mean = torch.tensor(config.normalization.mean)[:, None, None]
    std = torch.tensor(config.normalization.std)[:, None, None]
    values = (tensor.detach().cpu() * std + mean).clamp(0, 1)
    pixels = (values * 255).round().to(torch.uint8).permute(1, 2, 0).numpy()
    return Image.fromarray(pixels)


def load_validation_predictions(path: Path, manifest: DatasetManifest) -> NDArray[np.float64]:
    with path.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        rows = list(reader)
    expected = manifest.rows_for_split("validation")
    if [row["sample_id"] for row in rows] != [row.sample_id for row in expected]:
        raise ValueError(
            "Saved predictions do not have exactly the fixed validation membership/order."
        )
    classes = [definition.label for definition in manifest.classes]
    if any(
        int(row["true_index"]) != sample.class_index
        for row, sample in zip(rows, expected, strict=True)
    ):
        raise ValueError("Saved prediction labels disagree with the fixed class mapping.")
    probabilities = np.array(
        [[float(row[label]) for label in classes] for row in rows], dtype=np.float64
    )
    if not np.isfinite(probabilities).all() or np.any(probabilities < 0):
        raise ValueError("Saved probabilities are invalid.")
    np.testing.assert_allclose(probabilities.sum(axis=1), 1, atol=1e-6)
    return probabilities


def select_visual_rows(
    rows: Sequence[SampleRecord],
    probabilities: NDArray[np.float64],
    proxies: Sequence[dict[str, float]],
) -> dict[int, list[str]]:
    """Inspect every validation error and fixed extremes; proxies are not semantic diagnoses."""
    predictions = probabilities.argmax(axis=1)
    confidence = probabilities.max(axis=1)
    margin = np.sort(probabilities, axis=1)[:, -1] - np.sort(probabilities, axis=1)[:, -2]
    selected: dict[int, list[str]] = {}

    def add(index: int, category: str) -> None:
        categories = selected.setdefault(index, [])
        if category not in categories:
            categories.append(category)

    for index, row in enumerate(rows):
        if predictions[index] != row.class_index:
            add(index, "misclassified")
            add(
                index,
                "wrong_confidence_ge_0.9"
                if confidence[index] >= 0.9
                else "wrong_confidence_lt_0.9",
            )
    for class_index in sorted({row.class_index for row in rows}):
        correct = [
            index
            for index, row in enumerate(rows)
            if row.class_index == class_index and predictions[index] == class_index
        ]
        correct.sort(key=lambda index: (confidence[index], rows[index].sample_id))
        if correct:
            add(correct[0], "lowest_confidence_correct_per_class")
            add(correct[-1], "highest_confidence_correct_per_class")
    for index in sorted(range(len(rows)), key=lambda index: (margin[index], rows[index].sample_id))[
        :6
    ]:
        add(index, "smallest_top_two_probability_margin")
    for key, reverse, category in (
        ("sharpness", False, "low_sharpness_proxy"),
        ("brightness", False, "darkest_luminance_proxy"),
        ("brightness", True, "brightest_luminance_proxy"),
        ("aspect_extremeness", True, "non_square_aspect_proxy"),
    ):
        for index in sorted(
            range(len(rows)),
            key=lambda index: (proxies[index][key], rows[index].sample_id),
            reverse=reverse,
        )[:3]:
            add(index, category)
    return selected


def _sheet(
    path: Path, items: Sequence[tuple[str, Sequence[Image.Image]]], headings: Sequence[str]
) -> None:
    cell, row_height = 224, 336
    canvas = Image.new("RGB", (cell * len(headings), 30 + row_height * len(items)), "white")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default(size=13)
    for column, heading in enumerate(headings):
        draw.text((column * cell + 5, 5), heading, fill="black", font=font)
    for position, (label, images) in enumerate(items):
        y = 30 + position * row_height
        for column, image in enumerate(images):
            canvas.paste(ImageOps.contain(image, (cell, cell)), (column * cell, y))
        wrapped = "\n".join(textwrap.fill(line, width=88) for line in label.splitlines())
        draw.multiline_text((5, y + cell + 4), wrapped, fill="black", font=font, spacing=2)
    canvas.save(path)


def _source_metrics(
    rows: Sequence[SampleRecord], probabilities: NDArray[np.float64], classes: Sequence[str]
) -> dict[str, object]:
    groups: dict[str, list[int]] = {}
    for index, row in enumerate(rows):
        groups.setdefault(source_membership(row), []).append(index)
    return {
        "interpretation": (
            "Archive membership subsets, not independent verified field/plant domains; "
            "source archives overlap."
        ),
        "groups": {
            name: compute_metrics(
                [rows[index].class_index for index in indices], probabilities[indices], classes
            )
            for name, indices in groups.items()
        },
    }


def summarize_probes(
    labels: NDArray[np.int64],
    baseline: NDArray[np.float64],
    perturbed: dict[str, NDArray[np.float64]],
    classes: Sequence[str],
) -> dict[str, object]:
    """Compare each admitted probe with its SAME original subset, never mixed counts."""
    summary: dict[str, object] = {}
    for name, probabilities in perturbed.items():
        if probabilities.shape != baseline.shape:
            raise ValueError("Probe and original predictions must share membership and shape.")
        valid = np.isfinite(probabilities).all(axis=1)
        if not valid.any():
            summary[name] = {
                "evaluated": 0,
                "admission_failures": len(labels),
                "metrics": None,
                "matched_original_metrics": None,
                "undefined_reason": "No temporary probe input passed unchanged shared admission.",
            }
            continue
        reference = baseline[valid]
        selected = probabilities[valid]
        original_metrics = compute_metrics(labels[valid], reference, classes)
        probe_metrics = compute_metrics(labels[valid], selected, classes)
        class_changes = selected.argmax(axis=1) != reference.argmax(axis=1)
        summary[name] = {
            "evaluated": int(valid.sum()),
            "admission_failures": int((~valid).sum()),
            "class_change_count": int(class_changes.sum()),
            "class_change_rate": float(class_changes.mean()),
            "mean_confidence_change": float((selected.max(axis=1) - reference.max(axis=1)).mean()),
            "metrics": probe_metrics,
            "matched_original_metrics": original_metrics,
            "accuracy_change_vs_matched_original": (
                probe_metrics["accuracy"] - original_metrics["accuracy"]
            ),
        }
    return summary


def run_visual_review(
    manifest_path: Path, experiment: Path, output: Path, *, threads: int = 2
) -> dict[str, object]:
    root = load_dataset_path()
    output = output.resolve()
    if output.exists() or output == root or output.is_relative_to(root):
        raise ValueError("Diagnostics require a new output directory outside source data.")
    if threads not in (1, 2, 4):
        raise ValueError("Diagnostic CPU threads must be 1, 2 or 4.")
    manifest = load_manifest(manifest_path)
    archived = load_manifest(experiment / "dataset-manifest.json")
    if archived != manifest:
        raise ValueError("Experiment and fixed dataset index disagree.")
    config = load_config(experiment / "preprocessing.json")
    if config != manifest.load_preprocessing() or config.segmentation.mode != "disabled":
        raise ValueError("The original shared full-frame configuration is required.")
    classes = tuple(definition.label for definition in manifest.classes)
    summary = json.loads((experiment / "summary.json").read_text(encoding="utf-8"))
    checkpoint = (experiment / summary["best_checkpoint"]).resolve(strict=True)
    if (
        not checkpoint.is_relative_to(experiment.resolve())
        or hashlib.sha256(checkpoint.read_bytes()).hexdigest() != summary["best_checkpoint_sha256"]
    ):
        raise ValueError("Selected checkpoint path/hash disagrees with its immutable experiment.")
    saved = load_validation_predictions(experiment / "validation/predictions.csv", manifest)
    rows = manifest.rows_for_split("validation")
    labels = np.array([row.class_index for row in rows], dtype=np.int64)
    torch.set_num_threads(threads)
    torch.use_deterministic_algorithms(True)
    payload = read_checkpoint(
        checkpoint,
        class_names=classes,
        preprocessing_hash=config.fingerprint,
        manifest_hash=manifest.fingerprint,
    )
    model = build_model(len(classes), pretrained=False)
    restore_checkpoint(model, payload, len(classes))
    output.mkdir(parents=True, exist_ok=False)
    write_json(
        output / "plan.json",
        {
            "partition": "validation only; actual augmentation inspection uses train only",
            "suite_declared_before_execution": [asdict(item) for item in PERTURBATIONS],
            "model_selection_or_training": False,
            "test_image_access": False,
            "preprocessing_hash": config.fingerprint,
            "manifest_fingerprint": manifest.fingerprint,
            "checkpoint_sha256": summary["best_checkpoint_sha256"],
            "rotation_note": (
                "Fixed-canvas +/-5 degree probes can clip a thin corner region; "
                "this is an explicit stress probe, not production preprocessing."
            ),
            "temporary_encoding": (
                "Lossless PNG except the explicitly declared JPEG-quality-70 probe; "
                "shared admission limits are unchanged."
            ),
            "cam_source": "https://arxiv.org/abs/1610.02391",
            "limitations": (
                "Coarse final-feature Grad-CAM and geometric border/padding mass are not "
                "lesion ground truth, semantic background masks, causal proof or field accuracy."
            ),
        },
    )
    baseline = np.zeros_like(saved)
    perturbed = {specification.name: np.full_like(saved, np.nan) for specification in PERTURBATIONS}
    failures: list[dict[str, object]] = []
    proxies: list[dict[str, float]] = []
    changed: list[dict[str, object]] = []
    with (output / "robustness-cases.jsonl").open("x", encoding="utf-8") as journal:
        for index, row in enumerate(rows):
            source = (root / row.relative_path).resolve(strict=True)
            if not source.is_relative_to(root):
                raise ValueError("Validation path escapes source root.")
            result = preprocess_file(source, config)
            if result.metadata.image_hash != row.content_hash:
                raise ValueError("Validation bytes changed after the locked index.")
            gray = cv2.cvtColor(result.prepared_rgb, cv2.COLOR_RGB2GRAY)
            width, height = result.metadata.oriented_size
            proxies.append(
                {
                    "brightness": float(gray.mean()),
                    "sharpness": float(cv2.Laplacian(gray, cv2.CV_64F).var()),
                    "aspect_extremeness": max(width / height, height / width),
                }
            )
            tensors = [result.to_tensor()]
            accepted: list[str] = []
            for specification in PERTURBATIONS:
                try:
                    data = perturb_image(
                        result.standardized_rgb, specification, config.background_rgb
                    )
                    transformed = preprocess_image(data, config)
                    tensors.append(transformed.to_tensor())
                    accepted.append(specification.name)
                except PreprocessingError as error:
                    failures.append(
                        {
                            "sample_id": row.sample_id,
                            "perturbation": specification.name,
                            "code": error.code.value,
                        }
                    )
            with torch.inference_mode():
                probabilities = cast(Tensor, model(torch.stack(tensors))).softmax(dim=1).numpy()
            baseline[index] = probabilities[0]
            for position, name in enumerate(accepted, 1):
                vector = probabilities[position]
                perturbed[name][index] = vector
                record = {
                    "sample_id": row.sample_id,
                    "group_id": row.group_id,
                    "true_index": row.class_index,
                    "perturbation": name,
                    "original_prediction": int(probabilities[0].argmax()),
                    "perturbed_prediction": int(vector.argmax()),
                    "original_confidence": float(probabilities[0].max()),
                    "perturbed_confidence": float(vector.max()),
                    "confidence_change": float(vector.max() - probabilities[0].max()),
                    "true_class_probability_change": float(
                        vector[row.class_index] - probabilities[0, row.class_index]
                    ),
                }
                journal.write(json.dumps(record, allow_nan=False) + "\n")
                if record["original_prediction"] != record["perturbed_prediction"]:
                    changed.append(record)
            if (index + 1) % 50 == 0:
                print(
                    json.dumps(
                        {
                            "event": "validation_robustness_progress",
                            "completed": index + 1,
                            "total": len(rows),
                        }
                    ),
                    flush=True,
                )
    np.testing.assert_allclose(baseline, saved, atol=2e-6, rtol=1e-5)
    if not np.array_equal(baseline.argmax(axis=1), saved.argmax(axis=1)):
        raise ValueError("Reloaded validation predictions differ from the selected artifact.")
    robustness = summarize_probes(labels, baseline, perturbed, classes)
    write_json(
        output / "robustness.json",
        {
            "partition": "validation",
            "original_metrics": compute_metrics(labels, baseline, classes),
            "probes": robustness,
            "admission_failures": failures,
            "changed_cases": changed,
        },
    )
    write_json(output / "source-membership.json", _source_metrics(rows, baseline, classes))
    selection = select_visual_rows(rows, baseline, proxies)
    visual: list[dict[str, object]] = []
    sheet_items: list[tuple[str, Sequence[Image.Image]]] = []
    errors = baseline.argmax(axis=1) != labels
    confidence = baseline.max(axis=1)
    for index in sorted(
        selection,
        key=lambda position: (
            not errors[position],
            -confidence[position],
            rows[position].sample_id,
        ),
    ):
        row = rows[index]
        result = preprocess_file(root / row.relative_path, config)
        predicted = int(baseline[index].argmax())
        cam = grad_cam(model, result.to_tensor()[None], predicted)
        heat = cv2.applyColorMap((cam * 255).round().astype(np.uint8), cv2.COLORMAP_JET)
        heat = cv2.cvtColor(heat, cv2.COLOR_BGR2RGB)
        overlay = np.clip(0.55 * result.prepared_rgb + 0.45 * heat, 0, 255).astype(np.uint8)
        metadata = {
            "sample_id": row.sample_id,
            "group_id": row.group_id,
            "relative_path": row.relative_path,
            "partition": "validation",
            "true_label": row.label,
            "predicted_label": classes[predicted],
            "confidence": float(confidence[index]),
            "probabilities": list(map(float, baseline[index])),
            "selection_categories": selection[index],
            "pixel_proxies_not_semantic_labels": proxies[index],
            "source_membership": source_membership(row),
            "cam_target": "predicted class logit",
            "cam_geometry": cam_geometry(cam, result.metadata.content_bounds),
        }
        visual.append(metadata)
        label = (
            f"{len(visual) - 1:03d} {row.relative_path}\n"
            f"True: {row.label}; predicted: {classes[predicted]}\n"
            f"Confidence {confidence[index]:.4f}; ID {row.sample_id[:16]}\n"
            + ", ".join(selection[index])
        )
        sheet_items.append(
            (
                label,
                [
                    Image.fromarray(result.standardized_rgb),
                    Image.fromarray(result.prepared_rgb),
                    Image.fromarray(overlay),
                ],
            )
        )
    for start in range(0, len(sheet_items), 4):
        _sheet(
            output / f"validation-sheet-{start // 4:02d}.png",
            sheet_items[start : start + 4],
            ["Standardized source", "Shared model input", "Predicted-class Grad-CAM"],
        )
    write_json(output / "visual-samples.json", visual)
    augmentation_rows: list[SampleRecord] = []
    for class_index in range(len(classes)):
        candidates = sorted(
            [row for row in manifest.rows_for_split("train") if row.class_index == class_index],
            key=lambda row: row.sample_id,
        )
        selected_train = candidates[:2]
        minority = next(
            (row for row in candidates if source_membership(row) != "PlantVillage_color_overlap"),
            None,
        )
        if minority is not None and minority not in selected_train:
            selected_train.append(minority)
        augmentation_rows.extend(selected_train)
    augmentation_items: list[tuple[str, Sequence[Image.Image]]] = []
    augmentation_metadata: list[dict[str, object]] = []
    augmentation = training_augmentation(config)
    for position, row in enumerate(augmentation_rows):
        result = preprocess_file(root / row.relative_path, config)
        if result.metadata.image_hash != row.content_hash:
            raise ValueError("Training inspection source bytes changed.")
        images = [Image.fromarray(result.prepared_rgb)]
        for seed in (20261008, 20261009, 20261010):
            with torch.random.fork_rng():
                torch.manual_seed(seed + position)
                images.append(inverse_for_display(augmentation(result.to_tensor()), config))
        augmentation_items.append(
            (
                (
                    f"TRAIN ONLY {row.relative_path}\n{row.label}; ID {row.sample_id[:16]}\n"
                    "Actual Phase10 horizontal flip + small affine after shared normalization"
                ),
                images,
            )
        )
        augmentation_metadata.append(
            {
                "sample_id": row.sample_id,
                "group_id": row.group_id,
                "partition": "train",
                "relative_path": row.relative_path,
                "label": row.label,
                "seeds": [seed + position for seed in (20261008, 20261009, 20261010)],
            }
        )
    for start in range(0, len(augmentation_items), 4):
        _sheet(
            output / f"train-augmentation-{start // 4:02d}.png",
            augmentation_items[start : start + 4],
            [
                "Shared input",
                "Actual train augmentation 1",
                "Actual train augmentation 2",
                "Actual train augmentation 3",
            ],
        )
    write_json(output / "augmentation-samples.json", augmentation_metadata)
    total_parameters = sum(parameter.numel() for parameter in model.parameters())
    set_feature_training(model, enabled=False)
    frozen_trainable = sum(
        parameter.numel() for parameter in model.parameters() if parameter.requires_grad
    )
    set_feature_training(model, enabled=True)
    capacity = {
        "architecture": payload["architecture"],
        "parameters": total_parameters,
        "warmup_trainable_parameters": frozen_trainable,
        "fine_tune_trainable_parameters": sum(
            parameter.numel() for parameter in model.parameters() if parameter.requires_grad
        ),
        "parameter_storage_bytes": sum(
            parameter.numel() * parameter.element_size() for parameter in model.parameters()
        ),
        "checkpoint_bytes": checkpoint.stat().st_size,
        "feature_blocks": len(cast(nn.Sequential, model.features)),
        "cam_spatial_resolution": (
            "7x7 final features upsampled to 224; coarse diagnostic localization"
        ),
        "input_dimensions": [3, config.target_height, config.target_width],
        "torch": str(torch.__version__),
        "torchvision": __import__("torchvision").__version__,
        "runtime_threads": threads,
        "training_policy": (
            "2 epochs frozen features incl BN statistics; subsequent fine-tune all features "
            "with separate feature/head learning rates"
        ),
    }
    write_json(output / "capacity.json", capacity)
    result_summary: dict[str, object] = {
        "status": "completed",
        "validation_count": len(rows),
        "validation_error_count": int(errors.sum()),
        "high_confidence_errors_ge_0.9": int((errors & (confidence >= 0.9)).sum()),
        "visual_unique_contents": len(visual),
        "train_augmentation_contents": len(augmentation_rows),
        "model_changes": False,
        "test_image_access": False,
        "checkpoint_sha256": summary["best_checkpoint_sha256"],
        "manifest_fingerprint": manifest.fingerprint,
        "preprocessing_hash": config.fingerprint,
        "capacity": capacity,
    }
    write_json(output / "summary.json", result_summary)
    print(json.dumps({"event": "visual_review_completed", **result_summary}), flush=True)
    return result_summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--experiment", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--threads", type=int, default=2)
    args = parser.parse_args()
    run_visual_review(args.manifest, args.experiment, args.output, threads=args.threads)


if __name__ == "__main__":
    main()
