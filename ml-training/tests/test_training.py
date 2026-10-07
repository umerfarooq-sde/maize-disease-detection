"""Shared input, isolated augmentation, immutable selection and final-test guards."""

import hashlib
import json
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from unittest.mock import Mock

import pytest
import torch
from maizedoctor_preprocessing import PreprocessingConfig, load_config
from PIL import Image
from torch import Tensor, nn

import model as model_module
import train as trainer
import training_data
from dataset_preparation import (
    CLASS_LABELS,
    ClassDefinition,
    DatasetManifest,
    SampleRecord,
    SourceFile,
    SourceProvenance,
    SplitDefinition,
    canonical_hash,
    load_manifest,
)
from model import (
    ARCHITECTURE,
    WEIGHTS_URL,
    build_model,
    read_checkpoint,
    restore_checkpoint,
    save_checkpoint,
    validate_output,
)
from preprocessing import preprocess_file
from train import FinalTestGuard, TrainingSettings, optimizer_for, run_training, train_epoch
from training_data import MaizeDataset, make_loader, select_smoke_rows


class TinyModel(nn.Module):
    def __init__(self, class_count: int = 4) -> None:
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(3, 4, kernel_size=1), nn.ReLU(), nn.AdaptiveAvgPool2d(1), nn.Flatten()
        )
        self.classifier = nn.Sequential(nn.Linear(4, class_count))

    def forward(self, inputs: Tensor) -> Tensor:
        return self.classifier(self.features(inputs))


def tiny_factory(class_count: int, pretrained: bool, dropout: float) -> nn.Module:
    assert not pretrained
    return TinyModel(class_count)


@dataclass
class TrainingFixture:
    root: Path
    manifest_path: Path
    config_path: Path
    manifest: DatasetManifest
    config: PreprocessingConfig


@pytest.fixture
def training_fixture(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> TrainingFixture:
    root = tmp_path / "untouched originals"
    config_path = Path(__file__).parents[1] / "configs/full-frame-baseline.json"
    config = load_config(config_path)
    rows = []
    sources = []
    splits = {name: [] for name in ("train", "validation", "test")}
    for class_index, label in enumerate(CLASS_LABELS):
        directory = root / label
        directory.mkdir(parents=True)
        for number in range(14):
            path = directory / f"image-{number}.png"
            Image.new(
                "RGB", (48, 40), (20 + class_index * 40, 25 + number * 12, 235 - number * 9)
            ).save(path)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            relative = path.relative_to(root).as_posix()
            rows.append(
                SampleRecord(
                    sample_id=digest,
                    content_hash=digest,
                    pixel_hash=None,
                    label=label,
                    class_index=class_index,
                    relative_path=relative,
                    group_id=digest,
                    duplicate_paths=(),
                    provenance=SourceProvenance(references=(), original_ids=(), original_uuids=()),
                )
            )
            sources.append(
                SourceFile(
                    relative_path=relative,
                    content_hash=digest,
                    size_bytes=path.stat().st_size,
                    disposition="eligible",
                    sample_id=digest,
                )
            )
            split = "train" if number < 8 else "validation" if number < 12 else "test"
            splits[split].append(digest)
    manifest = DatasetManifest(
        version="synthetic-research-v1",
        fingerprint="0" * 64,
        classes=tuple(
            ClassDefinition(label=label, index=index) for index, label in enumerate(CLASS_LABELS)
        ),
        eligible=tuple(rows),
        excluded=(),
        source_inventory=tuple(sources),
        splits=SplitDefinition(**{name: tuple(ids) for name, ids in splits.items()}),
        split_seed=20261007,
        split_ratios=(0.7, 0.15, 0.15),
        preprocessing_config=config.model_dump(mode="json"),
        preprocessing_hash=config.fingerprint,
        input_hashes={
            "source_contents": canonical_hash(
                [
                    [source.relative_path, source.content_hash, source.size_bytes]
                    for source in sources
                ]
            )
        },
        research_policy={
            "academic_noncommercial_only": True,
            "raw_image_redistribution": False,
            "commercial_clearance": False,
        },
        counts={
            "source_files": 56,
            "source_unique_byte_contents": 56,
            "excluded_files": 0,
            "excluded_unique_contents": 0,
            "eligible_unique_samples": 56,
            "duplicate_aliases": 0,
            "eligible_groups": 56,
            "train": 32,
            "validation": 16,
            "test": 8,
        },
    )
    manifest = manifest.model_copy(
        update={
            "fingerprint": canonical_hash(manifest.model_dump(mode="json", exclude={"fingerprint"}))
        }
    )
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text(manifest.model_dump_json(indent=2), encoding="utf-8")
    load_manifest(manifest_path)
    monkeypatch.setattr(trainer, "load_dataset_path", lambda: root)
    monkeypatch.setattr(training_data, "load_dataset_path", lambda: root)
    return TrainingFixture(root, manifest_path, config_path, manifest, config)


def test_validation_uses_exact_shared_representation(training_fixture: TrainingFixture) -> None:
    row = training_fixture.manifest.rows_for_split("validation")[0]
    dataset = MaizeDataset([row], training_fixture.config, split="validation")
    actual, target, identifier = dataset[0]
    expected = preprocess_file(
        training_fixture.root / row.relative_path, training_fixture.config
    ).to_tensor()
    torch.testing.assert_close(actual, expected, rtol=0, atol=0)
    assert target == row.class_index and identifier == row.sample_id
    assert dataset.augmentation is None


@pytest.mark.parametrize("split", ["validation", "test"])
def test_augmentation_forbidden_outside_train(
    training_fixture: TrainingFixture, split: str
) -> None:
    with pytest.raises(ValueError, match="augmentation is forbidden"):
        MaizeDataset([], training_fixture.config, split=split, augment=True)
    with pytest.raises(ValueError, match="augmentation is forbidden"):
        MaizeDataset([], training_fixture.config, split=split, augmentation=lambda tensor: tensor)


def test_train_augmentation_runs_after_shared_preprocessing(
    training_fixture: TrainingFixture,
) -> None:
    row = training_fixture.manifest.rows_for_split("train")[0]
    seen = []

    def augmentation(tensor: Tensor) -> Tensor:
        seen.append(tensor.clone())
        return tensor + 0.125

    dataset = MaizeDataset(
        [row], training_fixture.config, split="train", augment=True, augmentation=augmentation
    )
    actual, _, _ = dataset[0]
    shared = preprocess_file(
        training_fixture.root / row.relative_path, training_fixture.config
    ).to_tensor()
    torch.testing.assert_close(seen[0], shared, rtol=0, atol=0)
    torch.testing.assert_close(actual, shared + 0.125, rtol=0, atol=0)
    assert make_loader(dataset, batch_size=2, seed=20261007).num_workers == 0


def test_sample_mutation_is_rejected(training_fixture: TrainingFixture) -> None:
    row = training_fixture.manifest.rows_for_split("train")[0]
    dataset = MaizeDataset([row], training_fixture.config, split="train")
    Image.new("RGB", (48, 40), (1, 2, 3)).save(training_fixture.root / row.relative_path)
    with pytest.raises(ValueError, match="Sample bytes changed"):
        dataset[0]


def test_smoke_subset_is_stable_balanced_and_stays_in_split(
    training_fixture: TrainingFixture,
) -> None:
    rows = training_fixture.manifest.rows_for_split("train")
    selected = select_smoke_rows(rows, 12)
    assert selected == select_smoke_rows(tuple(reversed(rows)), 12)
    assert Counter(row.class_index for row in selected) == {index: 3 for index in range(4)}
    assert {row.sample_id for row in selected} <= set(training_fixture.manifest.splits.train)
    assert not {row.sample_id for row in selected} & set(training_fixture.manifest.splits.test)


def test_final_test_guard_requires_selection_and_is_single_use() -> None:
    guard = FinalTestGuard(smoke=False)
    with pytest.raises(ValueError):
        guard.claim()
    guard.model_selected = True
    guard.claim()
    assert guard.evaluated
    with pytest.raises(ValueError):
        guard.claim()
    with pytest.raises(ValueError):
        FinalTestGuard(smoke=True, model_selected=True).claim()


def checkpoint_payload(model: nn.Module, fixture: TrainingFixture) -> dict[str, object]:
    return {
        "format_version": 1,
        "architecture": ARCHITECTURE,
        "class_names": list(CLASS_LABELS),
        "preprocessing_hash": fixture.config.fingerprint,
        "preprocessing": fixture.config.model_dump(mode="json"),
        "manifest_fingerprint": fixture.manifest.fingerprint,
        "state_dict": model.state_dict(),
    }


def test_checkpoint_is_immutable_and_reload_preserves_outputs(
    tmp_path: Path, training_fixture: TrainingFixture
) -> None:
    original = TinyModel().eval()
    path = tmp_path / "epoch-001.pt"
    save_checkpoint(path, checkpoint_payload(original, training_fixture))
    before = path.read_bytes()
    with pytest.raises(FileExistsError):
        save_checkpoint(path, checkpoint_payload(TinyModel(), training_fixture))
    assert path.read_bytes() == before
    payload = read_checkpoint(
        path,
        class_names=CLASS_LABELS,
        preprocessing_hash=training_fixture.config.fingerprint,
        manifest_hash=training_fixture.manifest.fingerprint,
    )
    restored = TinyModel()
    restore_checkpoint(restored, payload, 4)
    inputs = torch.zeros(2, 3, 224, 224)
    torch.testing.assert_close(original(inputs), restored(inputs), rtol=0, atol=0)
    with pytest.raises(ValueError, match="compatibility metadata"):
        read_checkpoint(
            path,
            class_names=CLASS_LABELS,
            preprocessing_hash="0" * 64,
            manifest_hash=training_fixture.manifest.fingerprint,
        )


def test_corrupted_pretrained_cache_is_rejected_before_deserialization(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(torch.hub, "get_dir", lambda: str(tmp_path))
    path = tmp_path / "checkpoints" / Path(WEIGHTS_URL).name
    path.parent.mkdir()
    path.write_bytes(b"untrusted or corrupted cache")
    monkeypatch.setattr(model_module, "mobilenet_v3_small", lambda **kwargs: TinyModel())
    deserialize = Mock(side_effect=AssertionError("Must never deserialize unverified bytes"))
    monkeypatch.setattr(torch, "load", deserialize)
    with pytest.raises(ValueError, match="checksum"):
        build_model(4)
    deserialize.assert_not_called()


def test_actual_mobilenet_has_four_finite_outputs_without_weights() -> None:
    torch.set_num_threads(4)
    validate_output(build_model(4, pretrained=False), 4)


def test_frozen_features_and_nonfinite_gradient_guard(training_fixture: TrainingFixture) -> None:
    model = TinyModel()
    settings = TrainingSettings(pretrained=False)
    optimizer = optimizer_for(model, settings, warmup=True)
    assert all(not parameter.requires_grad for parameter in model.features.parameters())
    before = model.classifier[0].weight.detach().clone()
    model.classifier[0].weight.register_hook(
        lambda gradient: torch.full_like(gradient, float("inf"))
    )
    loader = make_loader(
        MaizeDataset(
            training_fixture.manifest.rows_for_split("train")[:2],
            training_fixture.config,
            split="train",
        ),
        batch_size=2,
        seed=20261007,
    )
    with pytest.raises(RuntimeError, match="non-finite"):
        train_epoch(model, loader, optimizer, nn.CrossEntropyLoss(), frozen_features=True)
    torch.testing.assert_close(before, model.classifier[0].weight, rtol=0, atol=0)
    assert not model.features.training


def test_smoke_completes_without_decoding_test_and_refuses_overwrite(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, training_fixture: TrainingFixture
) -> None:
    processed = []
    shared = training_data.preprocess_file

    def observe(path: Path, config: PreprocessingConfig):
        processed.append(path.relative_to(training_fixture.root).as_posix())
        return shared(path, config)

    monkeypatch.setattr(training_data, "preprocess_file", observe)
    destination = tmp_path / "smoke-experiment"
    before = {path: path.read_bytes() for path in training_fixture.root.rglob("*.png")}
    settings = TrainingSettings(smoke=True, pretrained=False)
    result = run_training(
        training_fixture.manifest_path,
        training_fixture.config_path,
        destination,
        settings,
        model_factory=tiny_factory,
    )
    test_paths = {row.relative_path for row in training_fixture.manifest.rows_for_split("test")}
    assert not set(processed) & test_paths
    assert result["test_evaluated_once"] is False and result["epochs_completed"] == 1
    assert result["train_samples"] == 32 and result["validation_samples"] == 16
    assert not (destination / "test").exists()
    assert json.loads((destination / "used-partitions.json").read_text())["test"] == []
    assert (destination / "validation/confusion-matrix.png").is_file()
    payload = torch.load(destination / result["best_checkpoint"], weights_only=True)
    assert payload["dataset_version"] == training_fixture.manifest.version
    assert payload["research_policy"]["commercial_clearance"] is False
    assert all(path.read_bytes() == content for path, content in before.items())
    with pytest.raises(ValueError, match="must be new"):
        run_training(
            training_fixture.manifest_path,
            training_fixture.config_path,
            destination,
            settings,
            model_factory=tiny_factory,
        )


def test_full_fixture_evaluates_test_once_after_selected_reload(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, training_fixture: TrainingFixture
) -> None:
    events = []
    original_restore = trainer.restore_checkpoint
    original_preprocess = training_data.preprocess_file
    test_paths = {row.relative_path for row in training_fixture.manifest.rows_for_split("test")}

    def restore(*args, **kwargs):
        events.append("reload")
        return original_restore(*args, **kwargs)

    def observe(path: Path, config: PreprocessingConfig):
        if path.relative_to(training_fixture.root).as_posix() in test_paths:
            events.append("test")
        return original_preprocess(path, config)

    monkeypatch.setattr(trainer, "restore_checkpoint", restore)
    monkeypatch.setattr(training_data, "preprocess_file", observe)
    result = run_training(
        training_fixture.manifest_path,
        training_fixture.config_path,
        tmp_path / "full-fixture",
        TrainingSettings(warmup_epochs=1, fine_tune_epochs=1, pretrained=False),
        model_factory=tiny_factory,
    )
    assert result["epochs_completed"] == 2 and result["test_evaluated_once"] is True
    assert events.count("test") == len(test_paths)
    assert events[:2] == ["reload", "reload"]
    assert (tmp_path / "full-fixture/test/metrics.json").is_file()
    assert (tmp_path / "full-fixture/generalization.json").is_file()
