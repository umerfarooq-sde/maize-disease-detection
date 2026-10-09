"""Reproducible CPU transfer learning, validation selection and one final test pass."""

import argparse
import csv
import hashlib
import importlib.metadata
import json
import os
import platform
import random
import subprocess
import time
from collections.abc import Callable, Sequence
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Literal, cast

import numpy as np
import torch
from maizedoctor_preprocessing import load_config
from numpy.typing import NDArray
from torch import Tensor, nn
from torch.optim import AdamW, Optimizer
from torch.optim.lr_scheduler import ReduceLROnPlateau
from torch.utils.data import DataLoader

from configuration import load_dataset_path
from dataset_preparation import DatasetManifest, load_manifest, verify_manifest
from evaluation import EvaluationMetrics, analyze_generalization, compute_metrics, save_reports
from model import (
    ARCHITECTURE,
    WEIGHTS_NAME,
    WEIGHTS_SHA256,
    WEIGHTS_URL,
    build_model,
    read_checkpoint,
    restore_checkpoint,
    save_checkpoint,
    set_feature_training,
    validate_output,
)
from training_data import MaizeDataset, Sample, make_loader, select_smoke_rows

ROOT = Path(__file__).resolve().parents[1]
HistoryRow = dict[str, int | float | str]
ModelFactory = Callable[[int, bool, float], nn.Module]


@dataclass(frozen=True)
class TrainingSettings:
    seed: int = 20261007
    threads: int = 4
    batch_size: int = 16
    warmup_epochs: int = 2
    fine_tune_epochs: int = 10
    warmup_lr: float = 0.001
    feature_lr: float = 0.0001
    classifier_lr: float = 0.0003
    weight_decay: float = 0.0001
    dropout: float = 0.2
    patience: int = 3
    smoke: bool = False
    smoke_train_size: int = 32
    smoke_validation_size: int = 16
    pretrained: bool = True
    defer_test: bool = False

    def __post_init__(self) -> None:
        if (
            self.batch_size < 2
            or self.threads < 1
            or self.warmup_epochs < 1
            or self.fine_tune_epochs < 1
            or self.patience < 1
            or self.smoke_train_size < 2
            or self.smoke_validation_size < 2
            or min(self.warmup_lr, self.feature_lr, self.classifier_lr) <= 0
            or self.weight_decay < 0
            or not 0 <= self.dropout < 1
        ):
            raise ValueError("Training settings are invalid.")


@dataclass
class FinalTestGuard:
    smoke: bool
    model_selected: bool = False
    evaluated: bool = False
    deferred: bool = False

    def claim(self) -> None:
        if self.smoke or self.deferred or not self.model_selected or self.evaluated:
            raise ValueError("Final test requires a selected model and may run only once.")
        self.evaluated = True


@dataclass
class EvaluationResult:
    loss: float
    metrics: EvaluationMetrics
    labels: NDArray[np.int64]
    probabilities: NDArray[np.float32]
    sample_ids: tuple[str, ...]


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")


def configure_reproducibility(settings: TrainingSettings) -> None:
    random.seed(settings.seed)
    np.random.seed(settings.seed)
    torch.manual_seed(settings.seed)
    torch.set_num_threads(settings.threads)
    torch.use_deterministic_algorithms(True)
    torch.backends.cudnn.benchmark = False
    torch.hub.set_dir(str(ROOT / ".cache" / "torch"))


def environment_snapshot() -> dict[str, object]:
    distributions = sorted(
        (
            {"name": distribution.metadata["Name"], "version": distribution.version}
            for distribution in importlib.metadata.distributions()
        ),
        key=lambda distribution: distribution["name"].casefold(),
    )
    revision = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=False
    )
    dirty = subprocess.run(
        ["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True, check=False
    )
    hashes = {
        path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted((ROOT / "ml-training").glob("*.py"))
    }
    return {
        "python": platform.python_version(),
        "platform": platform.system(),
        "machine": platform.machine(),
        "logical_cpu_count": os.cpu_count(),
        "torch_threads": torch.get_num_threads(),
        "torch": str(torch.__version__),
        "cuda_available": torch.cuda.is_available(),
        "git_revision": revision.stdout.strip() if revision.returncode == 0 else None,
        "working_tree_dirty": bool(dirty.stdout.strip()),
        "source_hashes": hashes,
        "distributions": distributions,
    }


def train_epoch(
    model: nn.Module,
    loader: DataLoader[Sample],
    optimizer: Optimizer,
    criterion: nn.Module,
    *,
    frozen_features: bool,
) -> tuple[float, float]:
    model.train()
    if frozen_features:
        cast(nn.Module, model.features).eval()
    loss_total = 0.0
    correct = count = 0
    for batch_number, (images, indices, _) in enumerate(loader, 1):
        targets = cast(Tensor, indices)
        optimizer.zero_grad(set_to_none=True)
        logits = cast(Tensor, model(images))
        loss = cast(Tensor, criterion(logits, targets))
        if not torch.isfinite(loss):
            raise ValueError("Training loss became nonfinite.")
        loss.backward()  # type: ignore[no-untyped-call]  # PyTorch 2.10 omits this annotation.
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=5.0, error_if_nonfinite=True)
        optimizer.step()
        batch_size = targets.numel()
        loss_total += float(loss.detach()) * batch_size
        correct += int((logits.argmax(dim=1) == targets).sum())
        count += batch_size
        if batch_number % 25 == 0:
            print(json.dumps({"event": "train_progress", "batches": batch_number}), flush=True)
    if count == 0:
        raise ValueError("TRAIN partition is empty.")
    return loss_total / count, correct / count


def evaluate(
    model: nn.Module, loader: DataLoader[Sample], criterion: nn.Module, class_names: Sequence[str]
) -> EvaluationResult:
    model.eval()
    probabilities: list[NDArray[np.float32]] = []
    labels: list[NDArray[np.int64]] = []
    identifiers: list[str] = []
    loss_total = count = 0.0
    with torch.inference_mode():
        for images, indices, sample_ids in loader:
            targets = cast(Tensor, indices)
            logits = cast(Tensor, model(images))
            if (
                logits.shape != (targets.numel(), len(class_names))
                or not torch.isfinite(logits).all()
            ):
                raise ValueError("Evaluation output shape or values are invalid.")
            loss = cast(Tensor, criterion(logits, targets))
            if not torch.isfinite(loss):
                raise ValueError("Evaluation loss became nonfinite.")
            loss_total += float(loss) * targets.numel()
            count += targets.numel()
            probabilities.append(cast(NDArray[np.float32], logits.softmax(dim=1).numpy()))
            labels.append(cast(NDArray[np.int64], targets.numpy()))
            identifiers.extend(cast(Sequence[str], sample_ids))
    if count == 0:
        raise ValueError("Evaluation partition is empty.")
    joined_labels = np.concatenate(labels)
    joined_probabilities = np.concatenate(probabilities)
    return EvaluationResult(
        loss_total / count,
        compute_metrics(joined_labels, joined_probabilities, class_names),
        joined_labels,
        joined_probabilities,
        tuple(identifiers),
    )


def save_predictions(path: Path, result: EvaluationResult, class_names: Sequence[str]) -> None:
    with path.open("x", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["sample_id", "true_index", "predicted_index", *class_names])
        for sample_id, target, probabilities in zip(
            result.sample_ids, result.labels, result.probabilities, strict=True
        ):
            writer.writerow(
                [sample_id, int(target), int(probabilities.argmax()), *map(float, probabilities)]
            )


def save_evaluation(
    destination: Path,
    result: EvaluationResult,
    history: Sequence[HistoryRow],
    class_names: Sequence[str],
    *,
    split: Literal["train", "validation", "test"],
) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    save_predictions(destination / "predictions.csv", result, class_names)
    save_reports(
        destination,
        result.metrics,
        history,
        labels=result.labels,
        probabilities=result.probabilities,
        split=split,
    )


def optimizer_for(model: nn.Module, settings: TrainingSettings, *, warmup: bool) -> AdamW:
    set_feature_training(model, enabled=not warmup)
    classifier = cast(nn.Module, model.classifier)
    if warmup:
        return AdamW(
            classifier.parameters(), lr=settings.warmup_lr, weight_decay=settings.weight_decay
        )
    return AdamW(
        [
            {"params": cast(nn.Module, model.features).parameters(), "lr": settings.feature_lr},
            {"params": classifier.parameters(), "lr": settings.classifier_lr},
        ],
        weight_decay=settings.weight_decay,
    )


def run_training(
    manifest_path: Path,
    config_path: Path,
    destination: Path,
    settings: TrainingSettings,
    *,
    model_factory: ModelFactory | None = None,
) -> dict[str, object]:
    """A smoke is validation-only; full training unlocks final test after best reload."""
    dataset_root = load_dataset_path()
    destination = destination.resolve()
    if destination == dataset_root or destination.is_relative_to(dataset_root):
        raise ValueError("Experiment output must be outside source data.")
    if destination.exists():
        raise ValueError("Experiment output must be new; previous runs are immutable.")
    if not settings.smoke and not settings.pretrained and model_factory is None:
        raise ValueError("The full baseline requires the declared official pretrained weights.")
    manifest: DatasetManifest = load_manifest(manifest_path)
    verify_manifest(manifest, dataset_root=dataset_root)
    config = load_config(config_path)
    if config.fingerprint != manifest.preprocessing_hash or config.segmentation.mode != "disabled":
        raise ValueError("The dataset and full-frame preprocessing configuration disagree.")
    if config.target_height != 224 or config.target_width != 224:
        raise ValueError("The MobileNet baseline requires the pinned 224 input dimensions.")
    if config != manifest.load_preprocessing():
        raise ValueError("The manifest preprocessing content and checked-in settings disagree.")
    class_names = tuple(definition.label for definition in manifest.classes)
    configure_reproducibility(settings)
    destination.mkdir(parents=True, exist_ok=False)
    write_json(destination / "environment.json", environment_snapshot())
    write_json(destination / "hyperparameters.json", asdict(settings))
    write_json(destination / "preprocessing.json", config.model_dump(mode="json"))
    write_json(destination / "dataset-manifest.json", manifest.model_dump(mode="json"))
    write_json(
        destination / "class-map.json", [definition.model_dump() for definition in manifest.classes]
    )
    write_json(
        destination / "experiment.json",
        {
            "experiment_id": destination.name,
            "mode": "smoke" if settings.smoke else "full",
            "architecture": ARCHITECTURE,
            "pretrained_weights": WEIGHTS_NAME if settings.pretrained else None,
            "weights_url": WEIGHTS_URL if settings.pretrained else None,
            "weights_sha256": WEIGHTS_SHA256 if settings.pretrained else None,
            "dataset_version": manifest.version,
            "research_policy": manifest.research_policy,
            "manifest_fingerprint": manifest.fingerprint,
            "preprocessing_hash": config.fingerprint,
            "preprocessing_version": config.preprocessing_version,
            "test_selection_usage": "never",
            "final_test_deferred": settings.defer_test,
            "selection": "validation macro F1; validation loss breaks exact ties",
            "augmentation": (
                "TRAIN only: horizontal flip and small affine; normalized background fill"
            ),
        },
    )
    history: list[HistoryRow] = []
    guard = FinalTestGuard(smoke=settings.smoke, deferred=settings.defer_test)
    try:
        train_rows = manifest.rows_for_split("train")
        validation_rows = manifest.rows_for_split("validation")
        if settings.smoke:
            train_rows = select_smoke_rows(train_rows, settings.smoke_train_size)
            validation_rows = select_smoke_rows(validation_rows, settings.smoke_validation_size)
        write_json(
            destination / "used-partitions.json",
            {
                "train": [row.sample_id for row in train_rows],
                "validation": [row.sample_id for row in validation_rows],
                "test": [] if settings.smoke or settings.defer_test else list(manifest.splits.test),
                "smoke": settings.smoke,
            },
        )
        train_loader = make_loader(
            MaizeDataset(
                train_rows, config, split="train", augment=True, dataset_root=dataset_root
            ),
            batch_size=settings.batch_size,
            seed=settings.seed,
        )
        validation_loader = make_loader(
            MaizeDataset(validation_rows, config, split="validation", dataset_root=dataset_root),
            batch_size=settings.batch_size,
            seed=settings.seed,
        )
        model = (
            model_factory(len(class_names), settings.pretrained, settings.dropout)
            if model_factory
            else build_model(
                len(class_names), pretrained=settings.pretrained, dropout=settings.dropout
            )
        )
        if settings.pretrained and model_factory is None:
            weight_file = Path(torch.hub.get_dir()) / "checkpoints" / Path(WEIGHTS_URL).name
            weight_digest = hashlib.sha256(weight_file.read_bytes()).hexdigest()
            if weight_digest != WEIGHTS_SHA256:
                raise ValueError("Official pretrained weight checksum does not match provenance.")
            write_json(
                destination / "base-weights.json",
                {"name": WEIGHTS_NAME, "url": WEIGHTS_URL, "sha256": weight_digest},
            )
        validate_output(model, len(class_names))
        criterion = nn.CrossEntropyLoss()
        optimizer = optimizer_for(model, settings, warmup=True)
        scheduler = ReduceLROnPlateau(optimizer, mode="max", factor=0.5, patience=1)
        best_score: tuple[float, float] | None = None
        best_checkpoint: Path | None = None
        bad_epochs = 0
        total_epochs = 1 if settings.smoke else settings.warmup_epochs + settings.fine_tune_epochs
        started = time.monotonic()
        for epoch in range(1, total_epochs + 1):
            warmup = epoch <= settings.warmup_epochs
            if epoch == settings.warmup_epochs + 1:
                optimizer = optimizer_for(model, settings, warmup=False)
                scheduler = ReduceLROnPlateau(optimizer, mode="max", factor=0.5, patience=1)
                bad_epochs = 0
            train_loss, train_accuracy = train_epoch(
                model, train_loader, optimizer, criterion, frozen_features=warmup
            )
            validation = evaluate(model, validation_loader, criterion, class_names)
            macro_f1 = validation.metrics["macro_f1"]
            if macro_f1 is None:
                raise ValueError("Validation macro F1 is undefined; inspect split class coverage.")
            row: HistoryRow = {
                "epoch": epoch,
                "stage": "warmup" if warmup else "fine_tune",
                "learning_rate": float(optimizer.param_groups[0]["lr"]),
                "train_loss": train_loss,
                "validation_loss": validation.loss,
                "train_accuracy": train_accuracy,
                "validation_accuracy": validation.metrics["accuracy"],
                "validation_macro_f1": macro_f1,
            }
            history.append(row)
            with (destination / "epoch-history.jsonl").open("a", encoding="utf-8") as stream:
                stream.write(json.dumps(row, allow_nan=False) + "\n")
            score = (macro_f1, -validation.loss)
            if best_score is None or score > best_score:
                best_score = score
                bad_epochs = 0
                best_checkpoint = destination / "checkpoints" / f"epoch-{epoch:03d}.pt"
                save_checkpoint(
                    best_checkpoint,
                    {
                        "format_version": 1,
                        "architecture": ARCHITECTURE,
                        "class_names": list(class_names),
                        "class_to_index": {name: index for index, name in enumerate(class_names)},
                        "experiment_id": destination.name,
                        "dataset_version": manifest.version,
                        "research_policy": manifest.research_policy,
                        "pretrained_weights": WEIGHTS_NAME if settings.pretrained else None,
                        "weights_sha256": WEIGHTS_SHA256 if settings.pretrained else None,
                        "state_dict": {
                            name: tensor.detach().cpu().clone()
                            for name, tensor in model.state_dict().items()
                        },
                        "epoch": epoch,
                        "dropout": settings.dropout,
                        "seed": settings.seed,
                        "validation_macro_f1": macro_f1,
                        "validation_loss": validation.loss,
                        "manifest_fingerprint": manifest.fingerprint,
                        "preprocessing_hash": config.fingerprint,
                        "preprocessing_version": config.preprocessing_version,
                        "preprocessing": config.model_dump(mode="json"),
                        "hyperparameters": asdict(settings),
                    },
                )
            else:
                bad_epochs += 1
            scheduler.step(macro_f1)
            print(json.dumps({"event": "epoch_completed", **row}), flush=True)
            if not warmup and bad_epochs >= settings.patience:
                break
        if best_checkpoint is None:
            raise ValueError("Training produced no selected checkpoint.")
        payload = read_checkpoint(
            best_checkpoint,
            class_names=class_names,
            preprocessing_hash=config.fingerprint,
            manifest_hash=manifest.fingerprint,
        )
        restore_checkpoint(model, payload, len(class_names))
        reloaded = (
            model_factory(len(class_names), False, settings.dropout)
            if model_factory
            else build_model(len(class_names), pretrained=False, dropout=settings.dropout)
        )
        restore_checkpoint(reloaded, payload, len(class_names))
        first_validation = next(iter(validation_loader))[0]
        with torch.inference_mode():
            torch.testing.assert_close(
                model(first_validation), reloaded(first_validation), rtol=0, atol=0
            )
        model = reloaded
        guard.model_selected = True
        selected_train_loader = make_loader(
            MaizeDataset(train_rows, config, split="train", dataset_root=dataset_root),
            batch_size=settings.batch_size,
            seed=settings.seed,
        )
        selected_train = evaluate(model, selected_train_loader, criterion, class_names)
        selected_validation = evaluate(model, validation_loader, criterion, class_names)
        save_evaluation(destination / "train", selected_train, history, class_names, split="train")
        save_evaluation(
            destination / "validation",
            selected_validation,
            history,
            class_names,
            split="validation",
        )
        write_json(destination / "history.json", history)
        write_json(
            destination / "selected-metrics.json",
            {
                "best_epoch": payload["epoch"],
                "train": selected_train.metrics,
                "validation": selected_validation.metrics,
            },
        )
        write_json(
            destination / "generalization.json",
            analyze_generalization(selected_train.metrics, selected_validation.metrics, history),
        )
        final_metrics: EvaluationMetrics | None = None
        if not settings.smoke and not settings.defer_test:
            guard.claim()
            test_loader = make_loader(
                MaizeDataset(
                    manifest.rows_for_split("test"), config, split="test", dataset_root=dataset_root
                ),
                batch_size=settings.batch_size,
                seed=settings.seed,
            )
            final_test = evaluate(model, test_loader, criterion, class_names)
            final_metrics = final_test.metrics
            save_evaluation(destination / "test", final_test, history, class_names, split="test")
        result: dict[str, object] = {
            "status": "completed",
            "mode": "smoke" if settings.smoke else "full",
            "experiment_id": destination.name,
            "epochs_completed": len(history),
            "best_epoch": payload["epoch"],
            "best_checkpoint": best_checkpoint.relative_to(destination).as_posix(),
            "best_checkpoint_sha256": hashlib.sha256(best_checkpoint.read_bytes()).hexdigest(),
            "manifest_fingerprint": manifest.fingerprint,
            "preprocessing_hash": config.fingerprint,
            "train_samples": len(train_rows),
            "validation_samples": len(validation_rows),
            "test_evaluated_once": guard.evaluated,
            "final_test_deferred": settings.defer_test,
            "test_metrics": final_metrics,
            "elapsed_seconds": time.monotonic() - started,
        }
        write_json(destination / "summary.json", result)
        print(json.dumps({"event": "experiment_completed", **result}), flush=True)
        return result
    except Exception as error:
        write_json(
            destination / "failure.json",
            {
                "status": "failed",
                "error_type": type(error).__name__,
                "completed_epochs": len(history),
                "test_evaluated": guard.evaluated,
            },
        )
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--config", type=Path, default=Path(__file__).parent / "configs/full-frame-baseline.json"
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument(
        "--defer-test",
        action="store_true",
        help="Fit/select with train/validation only; defer test until the audit decision is frozen",
    )
    parser.add_argument("--batch-size", type=int, default=16)
    args = parser.parse_args()
    run_training(
        args.manifest,
        args.config,
        args.output,
        TrainingSettings(smoke=args.smoke, batch_size=args.batch_size, defer_test=args.defer_test),
    )


if __name__ == "__main__":
    main()
